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
      // No maximum line count on purpose. A `lineLimit(1...n)` cap is precisely
      // what turns a vertical `TextField` into a scrollable box: once the text
      // passes `n` lines the field stops growing and pans its content instead, so
      // the title looks like it scrolls up and down. Without a cap the field
      // always grows to fit, and `scrollDisabled` guarantees there is no inner
      // scroll view left to drag. Growth is bounded anyway — input stops at 32
      // characters.
      .lineLimit(nil)
      .scrollDisabled(true)
      .font(.system(size: TextStyle.articleTitleFontSize, weight: .bold))
      .foregroundStyle(TextStyle.textColor.color)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, TextStyle.editorHorizontalInset)
      .padding(.top, 12)
    }
  }
#endif
