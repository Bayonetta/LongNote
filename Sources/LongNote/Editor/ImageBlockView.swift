#if canImport(UIKit)
  import SwiftUI
  import UIKit
  import LongNoteCore

  /// An image paragraph: the downsampled photo with a caption `TextField` below and
  /// a delete button on top.
  @MainActor
  struct ImageBlockView: View {
    let document: ArticleDocument
    let paragraph: Paragraph

    @State private var loadedImage: UIImage?
    @State private var captionDraft: String = ""

    var body: some View {
      VStack(spacing: 6) {
        if let loadedImage {
          Image(uiImage: loadedImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .topTrailing) {
              Button {
                document.deleteParagraph(id: paragraph.id)
              } label: {
                Image(systemName: "xmark.circle.fill")
                  .font(.title3)
                  .foregroundStyle(.white)
                  .shadow(color: .black.opacity(0.5), radius: 2)
              }
              .padding(8)
            }

          TextField("Add a caption", text: $captionDraft)
            .font(.system(size: TextStyle.captionFontSize))
            .foregroundStyle(TextStyle.secondaryTextColor.color)
            .padding(.horizontal, 4)
            .onChange(of: captionDraft) { _, newValue in
              document.updateCaption(newValue, for: paragraph.id)
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
