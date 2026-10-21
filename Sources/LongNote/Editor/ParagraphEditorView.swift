#if canImport(UIKit)
  import SwiftUI
  import UIKit
  import LongNoteCore

  /// An editable text paragraph (title / header / body / quote / list) with its
  /// `RichTextView` and kind-specific decorations (quote bar, list bullet).
  @MainActor
  struct ParagraphEditorView: View {
    let document: ArticleDocument
    let paragraph: Paragraph

    /// Current laid-out height, reported by the text view so the row never fights
    /// the content.
    @State private var height: CGFloat

    init(document: ArticleDocument, paragraph: Paragraph) {
      self.document = document
      self.paragraph = paragraph
      _height = State(initialValue: ParagraphEditorView.estimatedHeight(for: paragraph))
    }

    // MARK: - Derived state

    private var placeholder: String {
      switch paragraph.kind {
      case .title: return "Enter a title"
      case .header: return "Enter a heading"
      case .quote: return "Enter a quote"
      case .list: return "Enter a list item"
      default: return "Start typing"
      }
    }

    private var isFocused: Bool {
      document.focus.focusedParagraphID == paragraph.id
    }

    private var requestedSelection: NSRange? {
      guard let request = document.focus.requestedSelection,
        request.paragraphID == paragraph.id
      else { return nil }
      return request.range
    }

    private var actionToApply: RichTextAction? {
      guard let action = document.pendingTextAction, action.0 == paragraph.id else { return nil }
      return action.1
    }

    private var isQuote: Bool { paragraph.kind == .quote }
    private var isList: Bool { paragraph.kind == .list }

    /// The original editor puts the gap *below* each paragraph only
    /// (`kEdgeInsets*` bottom): 30 pt for text blocks, `kLineHeightText` (8 pt)
    /// between list items, and 30 pt again after the last item of a run.
    private var bottomSpacing: CGFloat {
      if isQuote { return TextStyle.paragraphSpacing + 3 }
      if isList {
        return paragraph.isLastInList ? TextStyle.listLastSpacing : TextStyle.listItemSpacing
      }
      return TextStyle.paragraphSpacing
    }

    var body: some View {
      HStack(alignment: .top, spacing: isQuote ? 14 : 10) {
        if isQuote {
          quoteBar
        } else if isList {
          bullet
        }

        RichTextView(
          text: paragraph.text.styledText(paragraph.kind),
          placeholder: placeholder,
          isFocused: isFocused,
          shouldResign: document.focus.focusedParagraphID == nil,
          textInsets: UIEdgeInsets(top: 2, left: 0, bottom: 2, right: 0),
          selection: requestedSelection,
          actionToApply: actionToApply,
          initialTypingAttributes: paragraph.kind.baseAttributes,
          onTextChange: { document.updateText($0, for: paragraph.id) },
          onReturn: { document.handleReturn(id: paragraph.id, location: $0.location) },
          onBackspaceAtStart: { document.handleBackspaceAtStart(id: paragraph.id) },
          onDashSpace: { document.handleDashSpace(id: paragraph.id) },
          onPasteSplit: { document.handlePaste(id: paragraph.id, range: $0, text: $1) },
          onSelectionChange: { document.selectionChanged(id: paragraph.id, range: $0) },
          onHeightChange: { height = $0 },
          onBeginEditing: { document.focus.focusedParagraphID = paragraph.id },
          onEndEditing: {
            if document.focus.focusedParagraphID == paragraph.id {
              document.focus.focusedParagraphID = nil
            }
          },
          onActionApplied: { document.clearPendingTextAction() },
          onSelectionConsumed: { document.focus.clearSelectionRequest() }
        )
        .frame(height: height)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.leading, isQuote ? TextStyle.quoteInset : TextStyle.editorHorizontalInset)
      .padding(.trailing, isQuote ? TextStyle.quoteRightInset : TextStyle.editorHorizontalInset)
      .padding(.top, isQuote ? 3 : 0)
      .padding(.bottom, bottomSpacing)
    }

    private var quoteBar: some View {
      RoundedRectangle(cornerRadius: TextStyle.quoteBarWidth / 2)
        .fill(TextStyle.quoteBarColor.color)
        .frame(width: TextStyle.quoteBarWidth)
        .frame(minHeight: 28)
        .padding(.top, 4)
    }

    private var bullet: some View {
      Text("•")
        .font(.system(size: TextStyle.listFontSize, weight: .medium))
        .foregroundStyle(TextStyle.textColor.color)
        .padding(.top, 2)
        .frame(width: 22)
    }

    /// Rough first-frame height so the row isn't zero-height before the text view
    /// reports its real size. Corrected immediately after layout.
    private static func estimatedHeight(for paragraph: Paragraph) -> CGFloat {
      let length = paragraph.text.uiText.length
      let lineHeight = paragraph.kind.baseFont.lineHeight
      guard length > 0 else { return lineHeight + 6 }
      let charsPerLine = 40.0
      let lines = max(1.0, ceil(Double(length) / charsPerLine))
      return CGFloat(lines) * lineHeight + 6
    }
  }
#endif
