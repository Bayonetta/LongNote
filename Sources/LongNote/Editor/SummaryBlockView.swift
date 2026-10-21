#if canImport(UIKit)
  import SwiftUI
  import LongNoteCore

  /// The "summary" (lede) row. Tapping it opens a sheet editor; the text is
  /// stored on `Article.summary`.
  @MainActor
  struct SummaryBlockView: View {
    let document: ArticleDocument

    var body: some View {
      Button {
        document.isPresentingSummary = true
      } label: {
        HStack(spacing: 8) {
          Text(document.article.summary ?? "Add a summary (optional)")
            .font(.system(size: TextStyle.summaryFontSize))
            .foregroundStyle(
              document.article.summary == nil
                ? TextStyle.placeholderColor.color
                : TextStyle.secondaryTextColor.color
            )
            .lineLimit(4)
            .multilineTextAlignment(.leading)
          Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TextStyle.summaryBackgroundColor.color)
        .clipShape(RoundedRectangle(cornerRadius: 8))
      }
      .buttonStyle(.plain)
      .padding(.horizontal, TextStyle.editorHorizontalInset)
      .padding(.top, 8)
    }
  }
#endif
