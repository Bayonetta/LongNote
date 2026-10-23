#if canImport(UIKit)
  import SwiftUI
  import LongNoteCore

  /// The "summary" (lede) row — edited in place at the top of the editor, on the
  /// same light background used when exporting. Stored on `Article.summary`.
  @MainActor
  struct SummaryBlockView: View {
    let document: ArticleDocument

    var body: some View {
      TextField(
        "Add a summary (optional)",
        text: Binding(
          get: { document.article.summary ?? "" },
          set: { document.updateSummary($0) }
        ),
        axis: .vertical
      )
      // Same rule as the title: no line cap and no inner scrolling. The lede
      // grows with its text instead of turning into a four-line scrolling well.
      .lineLimit(nil)
      .scrollDisabled(true)
      .font(.system(size: TextStyle.summaryFontSize))
      .foregroundStyle(TextStyle.secondaryTextColor.color)
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(TextStyle.summaryBackgroundColor.color)
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .padding(.horizontal, TextStyle.editorHorizontalInset)
      .padding(.top, 8)
    }
  }
#endif
