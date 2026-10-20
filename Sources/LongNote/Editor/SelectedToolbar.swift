#if canImport(UIKit)
  import SwiftUI
  import UIKit
  import LongNoteCore

  /// Floating selection toolbar shown while text is selected: bold, strikethrough,
  /// color, and link. Button active states reflect the attributes at the selection
  /// start (`document.focusedSelectionAttributes`).
  @MainActor
  struct SelectedToolbar: View {
    let document: ArticleDocument

    @State private var showColorPanel = false
    @State private var showLinkPrompt = false
    @State private var linkDraft = ""

    private var isBold: Bool {
      guard let font = document.focusedSelectionAttributes[.font] as? UIFont else { return false }
      return font.fontDescriptor.symbolicTraits.contains(.traitBold)
    }

    private var isStrikethrough: Bool {
      (document.focusedSelectionAttributes[.strikethroughStyle] as? Int)
        == NSUnderlineStyle.single.rawValue
    }

    private var hasLink: Bool {
      document.focusedSelectionAttributes[.link] != nil
    }

    var body: some View {
      HStack(spacing: 20) {
        button("bold", isActive: isBold) {
          document.enqueueTextAction(.toggleBold)
        }
        button("strikethrough", isActive: isStrikethrough) {
          document.enqueueTextAction(.toggleStrikethrough)
        }
        button("paintpalette", isActive: false) {
          showColorPanel = true
        }
        button("link", isActive: hasLink) {
          if hasLink {
            document.enqueueTextAction(.setLink(nil))
          } else {
            showLinkPrompt = true
          }
        }
      }
      .font(.system(size: 20))
      .frame(maxWidth: .infinity)
      .padding(.vertical, 2)
      .popover(isPresented: $showColorPanel, arrowEdge: .bottom) {
        ColorPaletteView { color in
          document.enqueueTextAction(.setColor(color))
          showColorPanel = false
        }
        .frame(width: 260)
        .presentationCompactAdaptation(.popover)
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
    }

    private func button(_ icon: String, isActive: Bool, action: @escaping () -> Void) -> some View {
      Button(action: action) {
        Image(systemName: icon)
          .foregroundStyle(isActive ? TextStyle.accentColor.color : TextStyle.textColor.color)
      }
      .accessibilityLabel(icon)
    }
  }
#endif
