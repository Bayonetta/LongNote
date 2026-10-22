#if canImport(UIKit)
  import SwiftUI
  import UIKit
  import LongNoteCore

  /// The main editing page: cover → title → summary, followed by the paragraph
  /// stream, with the editing toolbar pinned to the bottom.
  ///
  /// Focus transfers between paragraphs are driven by `FocusCoordinator`; keyboard
  /// actions route into `ParagraphMutation` via `ArticleDocument`.
  @MainActor
  public struct ArticleEditorView: View {
    @Bindable private var document: ArticleDocument
    private let onClose: (() -> Void)?
    private let exportAction: (() -> Void)?

    /// Height of the on-screen keyboard; 0 when it is hidden. Drives the compose
    /// bar, which floats directly above the keyboard and disappears with it.
    @State private var keyboardInset: CGFloat = 0

    public init(
      document: ArticleDocument,
      onClose: (() -> Void)? = nil,
      exportAction: (() -> Void)? = nil
    ) {
      self._document = Bindable(document)
      self.onClose = onClose
      self.exportAction = exportAction
    }

    public var body: some View {
      VStack(spacing: 0) {
        ScrollViewReader { proxy in
          ScrollView {
            // A plain VStack, not a LazyVStack: row heights come from
            // `ParagraphMetrics` (the model), and every row must be laid out so a
            // paragraph that shrinks — after a Return split, say — releases its
            // space immediately instead of reserving a gap until it scrolls back
            // into view. Articles are tens of paragraphs, so the eager cost is
            // negligible (the original editor computed every row height too).
            VStack(spacing: 0) {
              CoverBlockView(document: document)
              TitleBlockView(document: document)
              SummaryBlockView(document: document)

              ForEach(document.article.paragraphs) { paragraph in
                paragraphRow(paragraph)
                  .id(paragraph.id)
              }

              Color.clear.frame(height: 40)
            }
          }
          .scrollDismissesKeyboard(.immediately)
          .onChange(of: document.focus.focusedParagraphID) { _, newID in
            guard let newID else { return }
            scrollTo(newID, using: proxy)
          }
        }
      }
      .background(Color(.systemBackground))
      // The compose bar is not pinned to the bottom of the screen: it rides on
      // the keyboard (like the original editor) and leaves with it.
      .overlay(alignment: .bottom) {
        if keyboardInset > 0 {
          toolbar
            .padding(.bottom, keyboardInset)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
      }
      .animation(.easeOut(duration: 0.25), value: keyboardInset)
      .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { note in
        withAnimation(.easeOut(duration: Self.keyboardDuration(in: note))) {
          keyboardInset = Self.keyboardHeight(in: note)
        }
      }
      .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { note in
        withAnimation(.easeOut(duration: Self.keyboardDuration(in: note))) {
          keyboardInset = 0
        }
      }
      .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
        withAnimation(.easeOut(duration: Self.keyboardDuration(in: note))) {
          keyboardInset = Self.keyboardHeight(in: note)
        }
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        if let onClose {
          ToolbarItem(placement: .topBarLeading) {
            Button(action: onClose) {
              Image(systemName: "xmark")
            }
            .accessibilityLabel("Close")
          }
        }
        if let exportAction {
          ToolbarItem(placement: .topBarTrailing) {
            Button(action: exportAction) {
              Image(systemName: "square.and.arrow.up")
            }
            .accessibilityLabel("Export long image")
          }
        }
      }
      .onDisappear { document.saveNow() }
    }

    // MARK: - Paragraph rows

    @ViewBuilder
    private func paragraphRow(_ paragraph: Paragraph) -> some View {
      switch paragraph.kind {
      case .image:
        ImageBlockView(document: document, paragraph: paragraph)
      case .divider:
        DividerBlockView(document: document, paragraph: paragraph)
      default:
        ParagraphEditorView(document: document, paragraph: paragraph)
      }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
      VStack(spacing: 0) {
        if document.hasSelectedText {
          SelectedToolbar(document: document)
          Divider()
        }
        EditorToolbar(document: document)
      }
    }

    /// Height the keyboard occupies at the bottom of the screen, taken from a
    /// keyboard notification's end frame (screen coordinates).
    private static func keyboardHeight(in note: Notification) -> CGFloat {
      guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
        frame.height > 1
      else {
        return 0
      }
      return max(UIScreen.main.bounds.height - frame.minY, 0)
    }

    private static func keyboardDuration(in note: Notification) -> Double {
      (note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
    }

    private func scrollTo(_ id: Paragraph.ID, using proxy: ScrollViewProxy) {
      DispatchQueue.main.async {
        withAnimation(.easeInOut(duration: 0.2)) {
          proxy.scrollTo(id, anchor: .center)
        }
      }
    }
  }
#endif
