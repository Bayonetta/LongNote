import LongNote
import SwiftUI

/// Renders the article as a long image, previews it, and offers share plus
/// save-to-photos. Falls back to a tile set when the content is too tall for a
/// single `UIImage` (see `ArticleImageRenderer`).
struct ExportView: View {
  let article: Article
  let store: FileArticleStore

  @State private var singleImage: UIImage?
  @State private var tiles: [UIImage] = []
  @State private var isRendering = false
  @State private var saveError: String?
  /// A temporary PNG of the first output image, shared as a file so every share
  /// target (AirDrop, Photos, Files, WeChat…) receives real image data.
  @State private var shareFile: URL?

  var body: some View {
    NavigationStack {
      Group {
        if isRendering {
          ProgressView("Rendering long image…")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let singleImage {
          LongImagePreview(image: singleImage)
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
            "Render failed", systemImage: "exclamationmark.triangle",
            description: Text("The article is too long or empty"))
        }
      }
      .navigationTitle("Preview")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItemGroup(placement: .confirmationAction) {
          if let shareFile {
            ShareLink(item: shareFile, preview: SharePreview("Long image", image: shareFile))
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
    shareFile = Self.makeShareFile(from: outputImages.first)
  }

  /// Writes the image to a temporary PNG so it can be shared as a file.
  private static func makeShareFile(from image: UIImage?) -> URL? {
    guard let image, let data = image.pngData() else { return nil }
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("LongNote-\(UUID().uuidString.prefix(8)).png")
    guard (try? data.write(to: url)) != nil else { return nil }
    return url
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
