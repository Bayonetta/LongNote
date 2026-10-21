#if canImport(UIKit)
  import SwiftUI
  import PhotosUI
  import LongNoteCore

  /// The main bottom toolbar: paragraph style menu, insert image, insert divider,
  /// link, and text color. Every item pairs its SF Symbol with a short caption
  /// so the bar is self-explanatory.
  @MainActor
  struct EditorToolbar: View {
    let document: ArticleDocument

    @State private var selectedImageItem: PhotosPickerItem?
    @State private var showColorPanel = false
    @State private var showLinkPrompt = false
    @State private var linkDraft = ""
    @State private var showImageLimitAlert = false

    private var focusedID: Paragraph.ID? {
      document.focus.focusedParagraphID
    }

    var body: some View {
      HStack(spacing: 4) {
        styleMenu
        imagePicker
        dividerButton
        linkButton
        colorButton
      }
      .padding(.horizontal, 8)
      .padding(.bottom, 4)
      .onChange(of: selectedImageItem) { _, item in
        guard let item else { return }
        Task {
          if let data = try? await item.loadTransferable(type: Data.self) {
            insertPickedImage(data)
          }
          selectedImageItem = nil
        }
      }
      .alert("Add Link", isPresented: $showLinkPrompt) {
        TextField("https://", text: $linkDraft)
        Button("Cancel", role: .cancel) { linkDraft = "" }
        Button("OK") {
          if let url = URL(string: linkDraft), url.scheme != nil {
            document.enqueueTextAction(.setLink(url))
          }
          linkDraft = ""
        }
      } message: {
        Text("The link applies to the current selection")
      }
      .alert("Up to 30 images", isPresented: $showImageLimitAlert) {
        Button("OK", role: .cancel) {}
      }
      .popover(isPresented: $showColorPanel, arrowEdge: .bottom) {
        ColorPaletteView { color in
          document.enqueueTextAction(.setColor(color))
          showColorPanel = false
        }
        .frame(width: 260)
        .presentationCompactAdaptation(.popover)
      }
    }

    // MARK: - Buttons

    private var styleMenu: some View {
      Menu {
        ForEach(ParagraphKind.styleKinds, id: \.self) { kind in
          Button {
            guard let id = focusedID else { return }
            document.setKind(kind, for: id)
          } label: {
            Label(styleName(kind), systemImage: styleIcon(kind))
          }
        }
      } label: {
        toolbarItem("textformat.size", caption: "Style")
      }
      .disabled(focusedID == nil)
    }

    private var imagePicker: some View {
      PhotosPicker(selection: $selectedImageItem, matching: .images) {
        toolbarItem("photo.on.rectangle.angled", caption: "Image")
      }
      .disabled(focusedID == nil)
    }

    private var dividerButton: some View {
      Button {
        guard let id = focusedID else { return }
        document.insertDivider(after: id)
      } label: {
        toolbarItem("minus", caption: "Divider")
      }
      .disabled(focusedID == nil)
    }

    private var linkButton: some View {
      Button {
        guard focusedID != nil else { return }
        showLinkPrompt = true
      } label: {
        toolbarItem("link", caption: "Link")
      }
      .disabled(focusedID == nil)
    }

    private var colorButton: some View {
      Button {
        guard focusedID != nil else { return }
        showColorPanel = true
      } label: {
        toolbarItem("paintpalette", caption: "Color")
      }
      .disabled(focusedID == nil)
    }

    /// One toolbar cell: SF Symbol above a small caption, filling its slot.
    /// The icon box has a fixed height so thin symbols (e.g. `minus`) keep the
    /// captions on one baseline.
    private func toolbarItem(_ icon: String, caption: String) -> some View {
      VStack(spacing: 3) {
        Image(systemName: icon)
          .font(.system(size: 17, weight: .medium))
          .frame(height: 22)
        Text(caption)
          .font(.system(size: 10))
      }
      .frame(maxWidth: .infinity)
      .accessibilityLabel(caption)
    }

    // MARK: - Helpers

    private func insertPickedImage(_ data: Data) {
      guard document.article.imageCount < 30 else {
        showImageLimitAlert = true
        return
      }
      guard let id = focusedID else { return }
      document.insertImage(data, after: id)
    }

    private func styleName(_ kind: ParagraphKind) -> String {
      switch kind {
      case .title: return "Title"
      case .header: return "Heading"
      case .quote: return "Quote"
      case .list: return "List"
      default: return "Body"
      }
    }

    private func styleIcon(_ kind: ParagraphKind) -> String {
      switch kind {
      case .title: return "textformat.size.larger"
      case .header: return "textformat.size"
      case .quote: return "text.quote"
      case .list: return "list.bullet"
      default: return "textformat"
      }
    }
  }
#endif
