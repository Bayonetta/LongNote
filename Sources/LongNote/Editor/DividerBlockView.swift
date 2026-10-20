#if canImport(UIKit)
  import SwiftUI
  import LongNoteCore

  /// A thin horizontal divider. Deleted either by backspace from the following
  /// paragraph (via `ParagraphMutation`) or through the context menu.
  @MainActor
  struct DividerBlockView: View {
    let document: ArticleDocument
    let paragraph: Paragraph

    var body: some View {
      Rectangle()
        .fill(TextStyle.dividerColor.color)
        .frame(height: 1)
        .padding(.horizontal, TextStyle.dividerInset)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .contextMenu {
          Button(role: .destructive) {
            document.deleteParagraph(id: paragraph.id)
          } label: {
            Label("Remove divider", systemImage: "minus.circle")
          }
        }
    }
  }
#endif
