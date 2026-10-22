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
    // TEMP DEBUG
    .task {
      let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("debug-focus.txt")
      while !Task.isCancelled {
        if let command = try? String(contentsOf: url, encoding: .utf8) {
          try? FileManager.default.removeItem(at: url)
          if let index = Int(command.trimmingCharacters(in: .whitespacesAndNewlines)),
            let document, index < document.article.paragraphs.count
          {
            document.focus.focus(document.article.paragraphs[index].id,
                                 selection: NSRange(location: 0, length: 0))
          }
        }
        try? await Task.sleep(nanoseconds: 300_000_000)
      }
    }
    .sheet(isPresented: $isPresentingExport) {
      if let document {
        ExportView(article: document.article, store: store)
      }
    }
  }
}
