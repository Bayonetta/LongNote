#if canImport(UIKit)
  import SwiftUI
  import UIKit
  import LongNoteCore

  /// An image paragraph.
  ///
  /// Mirrors the original editor's behaviour: the photo is shown clean — the
  /// caption sits on the image as a bottom overlay and the edit controls stay
  /// hidden until the image is tapped, so an article can be previewed without
  /// chrome in the way ("点击图片会出现更多操作，平时则隐藏起来").
  @MainActor
  struct ImageBlockView: View {
    let document: ArticleDocument
    let paragraph: Paragraph

    @State private var loadedImage: UIImage?
    @State private var captionDraft: String = ""
    @State private var isSelected = false

    var body: some View {
      VStack(spacing: 6) {
        if let loadedImage {
          Image(uiImage: loadedImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .overlay(alignment: .bottom) {
              if !isSelected, !captionDraft.isEmpty {
                captionOverlay
              }
            }
            .overlay(alignment: .topTrailing) {
              if isSelected {
                deleteButton
              }
            }
            .contentShape(Rectangle())
            .onTapGesture {
              withAnimation(.easeInOut(duration: 0.15)) { isSelected.toggle() }
            }

          if isSelected {
            TextField("Add a caption", text: $captionDraft)
              .font(.system(size: TextStyle.captionFontSize))
              .foregroundStyle(TextStyle.secondaryTextColor.color)
              .padding(.horizontal, 4)
              .onChange(of: captionDraft) { _, newValue in
                document.updateCaption(newValue, for: paragraph.id)
              }
          }
        }
      }
      .padding(.horizontal, TextStyle.editorHorizontalInset)
      .padding(.vertical, 6)
      .frame(maxWidth: .infinity)
      .onAppear {
        captionDraft = paragraph.image?.caption ?? ""
        reloadImage()
      }
    }

    // MARK: - Pieces

    /// Caption drawn over the photo's bottom edge, like the original.
    private var captionOverlay: some View {
      Text(captionDraft)
        .font(.system(size: TextStyle.captionFontSize))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
          LinearGradient(
            colors: [.black.opacity(0), .black.opacity(0.55)],
            startPoint: .top,
            endPoint: .bottom
          )
        )
    }

    private var deleteButton: some View {
      Button {
        document.deleteParagraph(id: paragraph.id)
      } label: {
        Image(systemName: "xmark.circle.fill")
          .font(.title3)
          .foregroundStyle(.white)
          .shadow(color: .black.opacity(0.5), radius: 2)
      }
      .padding(8)
      .accessibilityLabel("Delete image")
    }

    private func reloadImage() {
      guard let fileName = paragraph.image?.fileName,
        let data = try? document.store.loadImage(fileName, for: document.article.id)
      else {
        loadedImage = nil
        return
      }
      loadedImage = UIImage(data: data)
    }
  }
#endif
