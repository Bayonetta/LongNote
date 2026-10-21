#if canImport(UIKit)
  import SwiftUI
  import PhotosUI
  import LongNoteCore

  /// The main bottom toolbar — a faithful SwiftUI rebuild of the original
  /// WeicoNote compose bar: seven equal icon-only slots (46 pt tall) in the
  /// original order — photo, form (paragraph style), quote, list, link,
  /// divider, more — with SF Symbols standing in for the original artwork.
  @MainActor
  struct EditorToolbar: View {
    let document: ArticleDocument

    @State private var selectedImageItem: PhotosPickerItem?
    @State private var showLinkPrompt = false
    @State private var linkDraft = ""
    @State private var showImageLimitAlert = false

    private var focusedID: Paragraph.ID? {
      document.focus.focusedParagraphID
    }

    private var focusedKind: ParagraphKind? {
      document.paragraph(focusedID)?.kind
    }

    /// The paragraph a toolbar action applies to. Falls back to the last text
    /// paragraph, mirroring the original editor's `focuseOnLastLine`, so the
    /// bar works even when nothing holds the caret.
    private func targetID() -> Paragraph.ID? {
      document.focus.focusedParagraphID ?? document.focusLastTextParagraph()
    }

    var body: some View {
      HStack(spacing: 0) {
        imagePicker
        styleMenu
        quoteButton
        listButton
        linkButton
        dividerButton
        moreMenu
      }
      .frame(height: 46)
      .background(.bar)
      .overlay(alignment: .top) { Divider() }
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
    }

    // MARK: - Slots (original order)

    /// Photo — opens the system photo picker.
    private var imagePicker: some View {
      PhotosPicker(selection: $selectedImageItem, matching: .images) {
        barIcon("photo")
      }
      .accessibilityLabel("Insert image")
    }

    /// Form — paragraph style menu (title / heading / body / quote / list).
    private var styleMenu: some View {
      Menu {
        ForEach(ParagraphKind.styleKinds, id: \.self) { kind in
          Button {
            guard let id = targetID() else { return }
            document.setKind(kind, for: id)
          } label: {
            if focusedKind == kind {
              Label(styleName(kind), systemImage: "checkmark")
            } else {
              Text(styleName(kind))
            }
          }
        }
      } label: {
        barIcon("textformat.size")
      }
      .accessibilityLabel("Paragraph style")
    }

    /// Quote — toggles the block-quote style on the focused paragraph.
    private var quoteButton: some View {
      Button {
        guard let id = targetID() else { return }
        document.setKind(focusedKind == .quote ? .body : .quote, for: id)
      } label: {
        barIcon("text.quote", active: focusedKind == .quote)
      }
      .accessibilityLabel("Quote")
    }

    /// List — toggles the list style on the focused paragraph.
    private var listButton: some View {
      Button {
        guard let id = targetID() else { return }
        document.setKind(focusedKind == .list ? .body : .list, for: id)
      } label: {
        barIcon("list.bullet", active: focusedKind == .list)
      }
      .accessibilityLabel("List")
    }

    /// Link — attaches a URL to the current selection.
    private var linkButton: some View {
      Button {
        guard targetID() != nil else { return }
        showLinkPrompt = true
      } label: {
        barIcon("link")
      }
      .accessibilityLabel("Add link")
    }

    /// Line — inserts a divider below the focused paragraph.
    private var dividerButton: some View {
      Button {
        guard let id = targetID() else { return }
        document.insertDivider(after: id)
      } label: {
        barIcon("minus")
      }
      .accessibilityLabel("Insert divider")
    }

    /// More — the original insert panel. The monetisation entries (tip / paid
    /// reading) and "insert article" are publishing features outside this
    /// library's scope, so the menu keeps the insertable pieces it supports.
    private var moreMenu: some View {
      Menu {
        Button {
          document.isPresentingSummary = true
        } label: {
          Label("Summary", systemImage: "text.alignleft")
        }
        Button {
          guard let id = targetID() else { return }
          document.insertDivider(after: id)
        } label: {
          Label("Divider", systemImage: "minus")
        }
      } label: {
        barIcon("ellipsis")
      }
      .accessibilityLabel("More")
    }

    // MARK: - Pieces

    /// One icon-only slot that fills its share of the 46 pt bar.
    private func barIcon(_ name: String, active: Bool = false) -> some View {
      Image(systemName: name)
        .font(.system(size: 19))
        .foregroundStyle(active ? TextStyle.accentColor.color : TextStyle.textColor.color)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
    }

    private func insertPickedImage(_ data: Data) {
      guard document.article.imageCount < 30 else {
        showImageLimitAlert = true
        return
      }
      guard let id = targetID() else { return }
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
  }
#endif
