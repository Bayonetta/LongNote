#if canImport(UIKit)
  import SwiftUI
  import LongNoteCore

  /// The article title field at the top of the editor.
  ///
  /// The title is hard-capped at 32 characters: the binding refuses values
  /// beyond the limit, so typing simply stops there (mirroring the original
  /// editor's `textMaxCount`).
  @MainActor
  struct TitleBlockView: View {
    let document: ArticleDocument

    private static let maxLength = 32

    var body: some View {
      TextField(
        "Enter a title",
        text: Binding(
          get: { document.article.title },
          set: { newValue in
            // Ignore anything longer than the cap — the field just stops
            // accepting input (deleting and editing still work).
            if newValue.count <= Self.maxLength {
              document.updateTitle(newValue)
            }
          }
        ),
        axis: .vertical
      )
      .lineLimit(1...2)
      .font(.system(size: TextStyle.articleTitleFontSize, weight: .bold))
      .foregroundStyle(TextStyle.textColor.color)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, TextStyle.editorHorizontalInset)
      .padding(.top, 12)
    }
  }
#endif
