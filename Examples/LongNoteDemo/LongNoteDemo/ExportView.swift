import LongNote
import SwiftUI

/// Renders the article as a long image, previews it, and offers save-to-photos
/// plus share. Falls back to a tile set when the content is too tall for a single
/// `UIImage` (see `ArticleImageRenderer`).
struct ExportView: View {
  let article: Article
  let store: FileArticleStore

  @State private var singleImage: UIImage?
  @State private var tiles: [UIImage] = []
  @State private var isRendering = false
  @State private var saveError: String?

  var body: some View {
    NavigationStack {
      Group {
        if isRendering {
          ProgressView("Rendering long image…")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let singleImage {
          ScrollView([.horizontal, .vertical]) {
            Image(uiImage: singleImage)
              .resizable()
              .scaledToFit()
              .padding()
          }
        } else if !tiles.isEmpty {
          ScrollView(.horizontal) {
            HStack(spacing: 8) {
              ForEach(Array(tiles.enumerated()), id: \.offset) { _, image in
                Image(uiImage: image)
                  .resizable()
                  .scaledToFit()
                  .frame(height: 420)
              }
            }
            .padding()
          }
        } else {
          ContentUnavailableView(
            "Render failed", systemImage: "exclamationmark.triangle", description: Text("The article is too long or empty"))
        }
      }
      .navigationTitle("Preview")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItemGroup(placement: .confirmationAction) {
          if !outputImages.isEmpty {
            ShareLink(
              item: Image(uiImage: outputImages[0]),
              preview: SharePreview("Long image", image: Image(uiImage: outputImages[0]))
            )
            Button("Save to Photos") {
              saveToPhotoLibrary()
            }
          }
        }
      }
      .task { await render() }
      .alert(
        "Save failed",
        isPresented: Binding(
          get: { saveError != nil },
          set: { if !$0 { saveError = nil } }
        )
      ) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(saveError ?? "")
      }
    }
  }

  private var outputImages: [UIImage] {
    if let singleImage { return [singleImage] }
    return tiles
  }

  private func render() async {
    isRendering = true
    defer { isRendering = false }

    let imageLoader: (String) -> UIImage? = { fileName in
      guard let data = try? store.loadImage(fileName, for: article.id) else { return nil }
      return UIImage(data: data)
    }

    if let single = await ArticleImageRenderer.render(article, imageLoader: imageLoader) {
      singleImage = single
    } else {
      tiles = ArticleImageRenderer.renderTiles(article, imageLoader: imageLoader)
    }
  }

  private func saveToPhotoLibrary() {
    Task {
      do {
        for image in outputImages {
          try await image.saveToPhotoLibrary()
        }
      } catch {
        saveError = error.localizedDescription
      }
    }
  }
}
