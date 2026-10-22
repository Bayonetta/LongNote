#if canImport(UIKit)
  import Foundation
  import Observation
  import UIKit
  import LongNoteCore

  /// The editable document behind the article editor.
  ///
  /// Owns the `Article`, routes every text/keyboard event into the pure
  /// `ParagraphMutation` algorithms, tracks focus/selection for the toolbar, and
  /// debounce-saves to the injected `ArticleStore` (2 s after the last change,
  /// mirroring the original editor's ~3 s autosave timer).
  @MainActor
  @Observable
  public final class ArticleDocument {
    public var article: Article
    public let focus = FocusCoordinator()
    public let store: any ArticleStore

    /// Presented state for the summary editor sheet.
  
    // Selection tracking, read by the selection toolbar to reflect bold/color.
    public var focusedSelection: NSRange?
    public var focusedSelectionAttributes: [NSAttributedString.Key: Any] = [:]

    /// A rich-text action the toolbar enqueued for a specific paragraph; the
    /// paragraph view applies it to its live `UITextView` and clears it again.
    public var pendingTextAction: (Paragraph.ID, RichTextAction)?

    private var autosaveTask: Task<Void, Never>?

    public init(article: Article, store: any ArticleStore) {
      self.article = article
      self.store = store
    }

    // MARK: - Lookups

    public func paragraph(_ id: Paragraph.ID?) -> Paragraph? {
      guard let id else { return nil }
      return article.paragraphs.first { $0.id == id }
    }

    public var hasSelectedText: Bool {
      (focusedSelection?.length ?? 0) > 0
    }

    // MARK: - Applying mutation results

    public func apply(_ result: ParagraphMutation.Result) {
      article.paragraphs = result.paragraphs
      if let id = result.focusID {
        focus.focus(id, selection: result.selection)
      }
    }

    // MARK: - Keyboard routing (called by RichTextView delegates)

    public func handleReturn(id: Paragraph.ID, location: Int) {
      apply(ParagraphMutation.returnKey(article.paragraphs, id: id, location: location))
      scheduleAutosave()
    }

    public func handleBackspaceAtStart(id: Paragraph.ID) {
      apply(ParagraphMutation.mergeIntoPrevious(article.paragraphs, id: id))
      scheduleAutosave()
    }

    /// Typing "- " at the start of a paragraph converts it to a list item. When the
    /// dash was typed character-by-character it is already in the text, so it is
    /// stripped here before the conversion.
    public func handleDashSpace(id: Paragraph.ID) {
      var paragraphs = article.paragraphs
      if let index = paragraphs.firstIndex(where: { $0.id == id }) {
        let text = paragraphs[index].text.uiText
        if text.length > 0, ["-", "–", "—"].contains(String(text.string.prefix(1))) {
          let mutable = NSMutableAttributedString(attributedString: text)
          mutable.deleteCharacters(in: NSRange(location: 0, length: 1))
          paragraphs[index].text = CodableAttributedString(mutable)
        }
      }
      article.paragraphs = paragraphs
      apply(ParagraphMutation.convert(article.paragraphs, id: id, to: .list))
      pendingTextAction = (id, .setParagraphStyle(.list))
      scheduleAutosave()
    }

    public func handlePaste(id: Paragraph.ID, range: NSRange, text: String) {
      apply(
        ParagraphMutation.splitPastedText(article.paragraphs, id: id, range: range, pasted: text))
      scheduleAutosave()
    }

    // MARK: - Toolbar actions

    /// Focus the last editable paragraph, mirroring the original editor's
    /// `focuseOnLastLine` — toolbar buttons stay usable even when no paragraph
    /// currently holds the caret.
    @discardableResult
    public func focusLastTextParagraph() -> Paragraph.ID? {
      guard let last = article.paragraphs.last(where: { $0.kind.isTextKind }) else { return nil }
      focus.focus(last.id, selection: NSRange(location: 0, length: 0))
      return last.id
    }

    /// Change a paragraph's kind (H1 / H2 / body / quote / list). The paragraph
    /// view also restyles the whole text to the kind's base font/color.
    public func setKind(_ kind: ParagraphKind, for id: Paragraph.ID) {
      apply(ParagraphMutation.convert(article.paragraphs, id: id, to: kind))
      pendingTextAction = (id, .setParagraphStyle(kind))
      scheduleAutosave()
    }

    public func insertDivider(after id: Paragraph.ID) {
      apply(ParagraphMutation.insertDivider(article.paragraphs, after: id))
      scheduleAutosave()
    }

    public func deleteParagraph(id: Paragraph.ID) {
      apply(ParagraphMutation.delete(article.paragraphs, id: id))
      scheduleAutosave()
    }

    /// Persist a picked image (downsampled to ≤1000pt) into the article's
    /// `images/` directory and insert an image paragraph after `id`.
    public func insertImage(_ data: Data, after id: Paragraph.ID) {
      guard let image = UIImage(data: data) else { return }
      let downsampled = image.downsampledTo(maxEdge: 1000)
      guard let jpeg = downsampled.jpegDataForStorage() else { return }
      let fileName = "\(UUID().uuidString).jpg"
      _ = try? store.saveImage(jpeg, for: article.id, fileName: fileName)
      let meta = ParagraphImage(
        fileName: fileName,
        width: downsampled.size.width,
        height: downsampled.size.height,
        caption: ""
      )
      apply(ParagraphMutation.insertImage(article.paragraphs, after: id, image: meta))
      scheduleAutosave()
    }

    // MARK: - Metadata

    public func updateTitle(_ title: String) {
      article.title = title
      scheduleAutosave()
    }

    public func updateSummary(_ summary: String) {
      // Empty means "no lede" — keeps the placeholder and the export clean.
      article.summary = summary.isEmpty ? nil : summary
      scheduleAutosave()
    }

    public func setCoverImage(_ data: Data) {
      guard let image = UIImage(data: data) else { return }
      let downsampled = image.downsampledTo(maxEdge: 1600)
      guard let jpeg = downsampled.jpegDataForStorage() else { return }
      let fileName = "cover-\(UUID().uuidString).jpg"
      _ = try? store.saveImage(jpeg, for: article.id, fileName: fileName)
      article.cover = ArticleImage(
        fileName: fileName,
        width: downsampled.size.width,
        height: downsampled.size.height
      )
      scheduleAutosave()
    }

    public func removeCover() {
      article.cover = nil
      scheduleAutosave()
    }

    // MARK: - Text & selection updates (called by RichTextView)

    public func updateText(_ text: NSAttributedString, for id: Paragraph.ID) {
      guard let index = article.paragraphs.firstIndex(where: { $0.id == id }) else { return }
      article.paragraphs[index].text = CodableAttributedString(text)
      scheduleAutosave()
    }

    public func updateCaption(_ caption: String, for id: Paragraph.ID) {
      guard let index = article.paragraphs.firstIndex(where: { $0.id == id }) else { return }
      article.paragraphs[index].image?.caption = caption
      scheduleAutosave()
    }

    public func selectionChanged(id: Paragraph.ID, range: NSRange) {
      guard id == focus.focusedParagraphID else { return }
      focusedSelection = range

      guard let paragraph = paragraph(id) else {
        focusedSelectionAttributes = [:]
        return
      }
      let length = paragraph.text.uiText.length
      guard length > 0 else {
        focusedSelectionAttributes = paragraph.kind.baseAttributes
        return
      }
      let location = min(max(range.location, 0), length - 1)
      focusedSelectionAttributes = paragraph.text.uiText.attributes(
        at: location, effectiveRange: nil)
    }

    /// Ask the toolbar to deliver `action` to the currently focused paragraph.
    public func enqueueTextAction(_ action: RichTextAction) {
      guard let id = focus.focusedParagraphID else { return }
      pendingTextAction = (id, action)
    }

    public func clearPendingTextAction() {
      pendingTextAction = nil
    }

    // MARK: - Autosave

    /// Schedule a save 2 s after the last change (cancel-and-restart on each edit).
    private func scheduleAutosave() {
      autosaveTask?.cancel()
      autosaveTask = Task { [weak self] in
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        guard !Task.isCancelled else { return }
        self?.saveNow()
      }
    }

    /// Persist immediately, stamping `updatedAt`.
    public func saveNow() {
      var snapshot = article
      snapshot.updatedAt = Date()
      article.updatedAt = snapshot.updatedAt
      try? store.save(snapshot)
    }
  }
#endif
