#if canImport(UIKit)
  import SwiftUI
  import LongNoteCore

  /// The article title field at the top of the editor, capped at 32 characters with
  /// a soft word-count warning near the limit (mirrors the original editor's
  /// `textMaxCount` behavior).
  @MainActor
  struct TitleBlockView: View {
    let document: ArticleDocument

    private static let maxLength = 32

    var body: some View {
      VStack(alignment: .trailing, spacing: 4) {
        TextField(
          "Enter a title",
          text: Binding(
            get: { document.article.title },
            set: { newValue in
              if newValue.count <= Self.maxLength {
                document.updateTitle(newValue)
              }
            }
          )
        )
        .font(.system(size: TextStyle.articleTitleFontSize, weight: .bold))
        .foregroundStyle(TextStyle.textColor.color)
        .frame(maxWidth: .infinity, alignment: .leading)

        if document.article.title.count >= Self.maxLength - 4 {
          Text("Up to \(Self.maxLength) characters")
            .font(.caption)
            .foregroundStyle(TextStyle.secondaryTextColor.color)
        }
      }
      .padding(.horizontal, TextStyle.editorHorizontalInset)
      .padding(.top, 12)
    }
  }
#endif
