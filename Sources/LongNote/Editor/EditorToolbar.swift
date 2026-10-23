#if canImport(UIKit)
  import SwiftUI
  import PhotosUI
  import LongNoteCore

  /// The main bottom toolbar — a faithful SwiftUI rebuild of the original
  /// WeicoNote compose bar: six equal icon-only slots (46 pt tall) in the
  /// original order — photo, form (paragraph style), quote, list, link,
  /// divider — with SF Symbols standing in for the original artwork.
  @MainActor
  struct EditorToolbar: View {
    let document: ArticleDocument

    @State private var selectedImageItem: PhotosPickerItem?
    @State private var showLinkPrompt = false
    @State private var linkDraft = ""
    @State private var showImageLimitAlert = false
    /// The style strip is an inline row rather than a `Menu`: a menu is presented
    /// by the system with a slide-up animation, and the original editor simply
    /// swaps the row in.
    @State private var showStyleRow = false
    /// Captured when the link prompt opens: the alert resigns first responder,
    /// which clears the focused paragraph and the selection.
    @State private var linkTarget: (id: Paragraph.ID, selection: NSRange?)?

    private var focusedID: Paragraph.ID? {
      document.focus.focusedParagraphID
    }

    private var focusedKind: ParagraphKind? {
      document.paragraph(focusedID)?.kind
    }

    /// The paragraph a toolbar action applies to. Falls back to the last text
    /// paragraph, mirroring the original editor's `focuseOnLastLine`, so the
    /// bar works even when nothing holds the caret.
    private func targetID() -> Paragraph.ID? {
      document.focus.focusedParagraphID ?? document.focusLastTextParagraph()
    }

    var body: some View {
      VStack(spacing: 0) {
        if showStyleRow {
          styleRow
        }
        HStack(spacing: 0) {
          imagePicker
          styleButton
          quoteButton
          listButton
          linkButton
          dividerButton
        }
        .frame(height: 46)
      }
      .background(.bar)
      .overlay(alignment: .top) { Divider() }
      .onChange(of: selectedImageItem) { _, item in
        guard let item else { return }
        Task {
          if let data = try? await item.loadTransferable(type: Data.self) {
            insertPickedImage(data)
          }
          selectedImageItem = nil
        }
      }
      .alert("Add Link", isPresented: $showLinkPrompt) {
        TextField("https://", text: $linkDraft)
        Button("Cancel", role: .cancel) { linkDraft = "" }
        Button("OK") {
          defer { linkTarget = nil; linkDraft = "" }
          if let url = URL(string: linkDraft), url.scheme != nil, let linkTarget {
            document.enqueueTextAction(
              .setLink(url), for: linkTarget.id, selection: linkTarget.selection)
          }
        }
      } message: {
        Text("The link applies to the current selection")
      }
      .alert("Up to 30 images", isPresented: $showImageLimitAlert) {
        Button("OK", role: .cancel) {}
      }
    }

    // MARK: - Slots (original order)

    /// Photo — opens the system photo picker.
    private var imagePicker: some View {
      PhotosPicker(selection: $selectedImageItem, matching: .images) {
        barIcon("photo")
      }
      .accessibilityLabel("Insert image")
    }

    /// Aa — toggles the inline style strip (title / heading / body).
    private var styleButton: some View {
      Button {
        // No animation anywhere in this toggle: the strip is static chrome that
        // appears and disappears, not a presentation.
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
          showStyleRow.toggle()
        }
      } label: {
        barIcon("textformat.size", active: showStyleRow)
      }
      .accessibilityLabel("Paragraph style")
    }

    /// The style strip: three equal text slots, one per heading/body style.
    /// Quote and list are not here — the bar already has a button for each.
    private var styleRow: some View {
      HStack(spacing: 0) {
        ForEach(ParagraphKind.styleKinds, id: \.self) { kind in
          Button {
            guard let id = targetID() else { return }
            document.setKind(kind, for: id)
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
              showStyleRow = false
            }
          } label: {
            Text(styleName(kind))
              .font(.system(size: 14, weight: focusedKind == kind ? .semibold : .regular))
              .foregroundStyle(
                focusedKind == kind ? TextStyle.accentColor.color : TextStyle.textColor.color
              )
              .frame(maxWidth: .infinity, maxHeight: .infinity)
              .contentShape(Rectangle())
          }
          .accessibilityLabel(styleName(kind))
        }
      }
      .frame(height: 40)
      .overlay(alignment: .bottom) { Divider() }
    }

    /// Quote — toggles the block-quote style on the focused paragraph.
    private var quoteButton: some View {
      Button {
        guard let id = targetID() else { return }
        document.setKind(focusedKind == .quote ? .body : .quote, for: id)
      } label: {
        barIcon("text.quote", active: focusedKind == .quote)
      }
      .accessibilityLabel("Quote")
    }

    /// List — toggles the list style on the focused paragraph.
    private var listButton: some View {
      Button {
        guard let id = targetID() else { return }
        document.setKind(focusedKind == .list ? .body : .list, for: id)
      } label: {
        barIcon("list.bullet", active: focusedKind == .list)
      }
      .accessibilityLabel("List")
    }

    /// Link — attaches a URL to the current selection.
    private var linkButton: some View {
      Button {
        // Remember where the link goes *before* the alert takes over.
        if let id = targetID() {
          linkTarget = (id, document.focusedSelection)
          showLinkPrompt = true
        }
      } label: {
        barIcon("link")
      }
      .accessibilityLabel("Add link")
    }

    /// Line — inserts a divider below the focused paragraph.
    private var dividerButton: some View {
      Button {
        guard let id = targetID() else { return }
        document.insertDivider(after: id)
      } label: {
        barIcon("minus")
      }
      .accessibilityLabel("Insert divider")
    }

    // MARK: - Pieces

    /// One icon-only slot that fills its share of the 46 pt bar.
    private func barIcon(_ name: String, active: Bool = false) -> some View {
      Image(systemName: name)
        .font(.system(size: 19))
        .foregroundStyle(active ? TextStyle.accentColor.color : TextStyle.textColor.color)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
    }

    private func insertPickedImage(_ data: Data) {
      guard document.article.imageCount < 30 else {
        showImageLimitAlert = true
        return
      }
      guard let id = targetID() else { return }
      document.insertImage(data, after: id)
    }

    private func styleName(_ kind: ParagraphKind) -> String {
      switch kind {
      case .title: return "Title"
      case .header: return "Heading"
      case .quote: return "Quote"
      case .list: return "List"
      default: return "Body"
      }
    }
  }
#endif
