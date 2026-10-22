#if canImport(UIKit)
  import SwiftUI
  import UIKit
  import LongNoteCore

  /// The selection bar that slides in above the main toolbar while text is
  /// selected — four equal slots (46 pt tall) in the original order: bold,
  /// strikethrough, link, color. The color slot carries a small swatch of the
  /// current text color, as the original did.
  @MainActor
  struct SelectedToolbar: View {
    let document: ArticleDocument

    @State private var showColorPanel = false
    @State private var showLinkPrompt = false
    @State private var linkDraft = ""
    /// Captured when the link prompt opens (the alert clears focus/selection).
    @State private var linkTarget: (id: Paragraph.ID, selection: NSRange?)?

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

    private var currentColor: Color {
      (document.focusedSelectionAttributes[.foregroundColor] as? UIColor).map(Color.init)
        ?? TextStyle.textColor.color
    }

    var body: some View {
      HStack(spacing: 0) {
        Button {
          document.enqueueTextAction(.toggleBold)
        } label: {
          barIcon("bold", active: isBold)
        }
        .accessibilityLabel("Bold")

        Button {
          document.enqueueTextAction(.toggleStrikethrough)
        } label: {
          barIcon("strikethrough", active: isStrikethrough)
        }
        .accessibilityLabel("Strikethrough")

        Button {
          if hasLink {
            if let id = document.focus.focusedParagraphID {
              document.enqueueTextAction(
                .setLink(nil), for: id, selection: document.focusedSelection)
            }
          } else if let id = document.focus.focusedParagraphID {
            linkTarget = (id, document.focusedSelection)
            showLinkPrompt = true
          }
        } label: {
          barIcon("link", active: hasLink)
        }
        .accessibilityLabel("Link")

        Button {
          showColorPanel = true
        } label: {
          colorIcon
        }
        .accessibilityLabel("Text color")
      }
      .frame(height: 46)
      .background(.bar)
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
          defer { linkTarget = nil; linkDraft = "" }
          if let url = URL(string: linkDraft), url.scheme != nil, let linkTarget {
            document.enqueueTextAction(
              .setLink(url), for: linkTarget.id, selection: linkTarget.selection)
          }
        }
      } message: {
        Text("The link applies to the current selection")
      }
    }

    // MARK: - Pieces

    private func barIcon(_ name: String, active: Bool) -> some View {
      Image(systemName: name)
        .font(.system(size: 19))
        .foregroundStyle(active ? TextStyle.accentColor.color : TextStyle.textColor.color)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
    }

    /// Palette symbol with the current text color shown as a swatch beneath it.
    private var colorIcon: some View {
      VStack(spacing: 3) {
        Image(systemName: "paintpalette")
          .font(.system(size: 19))
        RoundedRectangle(cornerRadius: 1.5)
          .fill(currentColor)
          .frame(width: 18, height: 4)
          .overlay(
            RoundedRectangle(cornerRadius: 1.5)
              .strokeBorder(Color.primary.opacity(0.15), lineWidth: 0.5)
          )
      }
      .foregroundStyle(TextStyle.textColor.color)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .contentShape(Rectangle())
    }
  }
#endif
