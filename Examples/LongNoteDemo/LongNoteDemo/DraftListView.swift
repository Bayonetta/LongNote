import LongNote
import SwiftUI

/// The draft inbox: list saved articles, open one to edit, create a new one, or
/// delete. New articles are persisted immediately so the editor can autosave on
/// top of them.
struct DraftListView: View {
  let store: FileArticleStore

  @State private var drafts: [Article] = []
  @State private var path: [Article.ID] = []
  @AppStorage("didSeedSample") private var didSeedSample = false

  var body: some View {
    NavigationStack(path: $path) {
      Group {
        if drafts.isEmpty {
          VStack(spacing: 20) {
            ContentUnavailableView(
              "No drafts yet",
              systemImage: "doc.text",
              description: Text("Tap + in the top right to start writing, or load a sample article")
            )
            Button("Load Sample Article") {
              loadSample()
            }
            .buttonStyle(.borderedProminent)
          }
        } else {
          List {
            ForEach(drafts) { draft in
              NavigationLink(value: draft.id) {
                row(draft)
              }
            }
            .onDelete(perform: delete)
          }
        }
      }
      .navigationTitle("Drafts")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button(action: createArticle) {
            Image(systemName: "plus")
          }
          .accessibilityLabel("New article")
        }
      }
      .navigationDestination(for: Article.ID.self) { id in
        EditorScreen(store: store, articleID: id)
      }
      .onAppear {
        reload()
        maybeSeedSample()
      }
    }
  }

  // MARK: - Row

  private func row(_ draft: Article) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(draft.title.isEmpty ? "Untitled" : draft.title)
        .font(.headline)
        .lineLimit(1)
      HStack(spacing: 8) {
        Text(draft.updatedAt.formatted(date: .abbreviated, time: .shortened))
        Text("· \(draft.paragraphs.count) paragraphs")
      }
      .font(.caption)
      .foregroundStyle(.secondary)
    }
  }

  // MARK: - Actions

  private func createArticle() {
    let article = Article.empty()
    try? store.save(article)
    path.append(article.id)
  }

  /// First launch seeds one sample article so the demo (and any screenshot)
  /// opens straight into a fully populated editor.
  private func maybeSeedSample() {
    guard !didSeedSample, drafts.isEmpty else { return }
    didSeedSample = true
    loadSample()
  }

  private func loadSample() {
    let article = SampleArticle.make(store: store)
    try? store.save(article)
    reload()
    // Defer the push by one runloop: mutating `path` in the same tick as the
    // `drafts` update that flips the empty-state branch would be dropped.
    DispatchQueue.main.async {
      path.append(article.id)
    }
  }

  private func delete(at offsets: IndexSet) {
    for index in offsets {
      try? store.delete(drafts[index].id)
    }
    reload()
  }

  private func reload() {
    drafts = (try? store.loadAll()) ?? []
  }
}
