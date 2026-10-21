#if canImport(UIKit)
  import SwiftUI
  import PhotosUI
  import UIKit
  import LongNoteCore

  /// The 16:9 cover banner at the top of the editor: shows the current cover with a
  /// remove button, or a "set cover" `PhotosPicker` when empty.
  @MainActor
  struct CoverBlockView: View {
    let document: ArticleDocument

    @State private var selectedItem: PhotosPickerItem?
    @State private var loadedImage: UIImage?

    var body: some View {
      // A fixed 16:9 slot: `Color.clear` pins the height, and the cover image is
      // an overlay that fills it. A tall image is centre-cropped (`scaledToFill`
      // + `clipped`) instead of growing the row.
      Color.clear
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .overlay {
          if let loadedImage {
            Image(uiImage: loadedImage)
              .resizable()
              .scaledToFill()
          } else {
            PhotosPicker(selection: $selectedItem, matching: .images) {
              ZStack {
                Rectangle()
                  .fill(Color(.secondarySystemBackground))
                VStack(spacing: 6) {
                  Image(systemName: "photo.on.rectangle.angled")
                    .font(.title2)
                  Text("Add cover")
                    .font(.system(size: TextStyle.captionFontSize))
                }
                .foregroundStyle(.secondary)
              }
            }
            .buttonStyle(.plain)
          }
        }
        .overlay(alignment: .topTrailing) {
          if loadedImage != nil {
            Button {
              document.removeCover()
            } label: {
              Image(systemName: "xmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.4), radius: 2)
            }
            .padding(10)
          }
        }
        .clipped()
        .onAppear(perform: reloadCover)
        .onChange(of: document.article.cover) { _, _ in reloadCover() }
        .onChange(of: selectedItem) { _, item in
          guard let item else { return }
          Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
              document.setCoverImage(data)
            }
            selectedItem = nil
          }
        }
    }

    private func reloadCover() {
      guard let fileName = document.article.cover?.fileName else {
        loadedImage = nil
        return
      }
      guard let data = try? document.store.loadImage(fileName, for: document.article.id) else {
        loadedImage = nil
        return
      }
      loadedImage = UIImage(data: data)
    }
  }
#endif
