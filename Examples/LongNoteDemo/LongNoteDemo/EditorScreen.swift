import LongNote
import SwiftUI

/// Hosts `ArticleEditorView` for one saved article: loads the document, wires the
/// close and export actions.
struct EditorScreen: View {
  let store: FileArticleStore
  let articleID: Article.ID

  @Environment(\.dismiss) private var dismiss
  @State private var document: ArticleDocument?
  @State private var isPresentingExport = false

  var body: some View {
    Group {
      if let document {
        ArticleEditorView(
          document: document,
          onClose: { dismiss() },
          exportAction: { isPresentingExport = true }
        )
      } else {
        ProgressView()
      }
    }
    .task {
      guard document == nil else { return }
      if let article = try? store.load(articleID) {
        document = ArticleDocument(article: article, store: store)
      }
    }
    .sheet(isPresented: $isPresentingExport) {
      if let document {
        ExportView(article: document.article, store: store)
      }
    }
  }
}
