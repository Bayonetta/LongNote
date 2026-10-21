#if canImport(UIKit)
  import UIKit
  import LongNoteCore

  /// Row heights for text paragraphs, computed from the model.
  ///
  /// The editor is a `LazyVStack`: rows that scroll out of view are released, so
  /// a height measured by the live `UITextView` stops being updated for a row
  /// that is off-screen — after a Return split the released head row kept its
  /// old (taller) height and reserved a large gap. Deriving the height from the
  /// paragraph itself keeps every row's layout correct whether or not its text
  /// view is alive, and it makes the layout a pure function of the document.
  enum ParagraphMetrics {

    /// Height the paragraph's text needs, including the text view's vertical
    /// insets and a 2 pt safety margin.
    static func height(for paragraph: Paragraph) -> CGFloat {
      let insets = paragraph.kind.textInsets
      guard paragraph.kind.isTextKind else {
        return paragraph.kind.baseFont.lineHeight + insets.top + insets.bottom + 2
      }
      guard !paragraph.text.isEmpty else {
        return paragraph.kind.baseFont.lineHeight + insets.top + insets.bottom + 2
      }

      // The editor spans the screen width, so the wrapping width is the screen
      // minus the paragraph's insets (the original editor measured the same way).
      let width = UIScreen.main.bounds.width - paragraph.kind.textHorizontalInset
      guard width > 0 else {
        return paragraph.kind.baseFont.lineHeight + insets.top + insets.bottom + 2
      }

      let text = paragraph.text.styledText(paragraph.kind)
      let rect = text.boundingRect(
        with: CGSize(width: width, height: .greatestFiniteMagnitude),
        options: [.usesLineFragmentOrigin, .usesFontLeading],
        context: nil
      )
      return ceil(rect.height + insets.top + insets.bottom) + 2
    }
  }
#endif
