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
            LazyVStack(spacing: 0) {
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
        .safeAreaInset(edge: .bottom, spacing: 0) {
          toolbar
        }
      }
      .background(Color(.systemBackground))
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
      .sheet(isPresented: $document.isPresentingSummary) {
        SummaryEditorSheet(document: document)
      }
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
      VStack(spacing: 6) {
        if document.hasSelectedText {
          SelectedToolbar(document: document)
        }
        EditorToolbar(document: document)
      }
      .padding(.top, 8)
      .background(.bar)
    }

    private func scrollTo(_ id: Paragraph.ID, using proxy: ScrollViewProxy) {
      DispatchQueue.main.async {
        withAnimation(.easeInOut(duration: 0.2)) {
          proxy.scrollTo(id, anchor: .center)
        }
      }
    }
  }

  /// Sheet for editing the article summary (lede).
  @MainActor
  private struct SummaryEditorSheet: View {
    let document: ArticleDocument
    @Environment(\.dismiss) private var dismiss
    @State private var draft: String = ""

    var body: some View {
      NavigationStack {
        TextEditor(text: $draft)
          .padding()
          .navigationTitle("Summary")
          .navigationBarTitleDisplayMode(.inline)
          .toolbar {
            ToolbarItem(placement: .cancellationAction) {
              Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
              Button("Save") {
                document.updateSummary(draft)
                dismiss()
              }
              .fontWeight(.semibold)
            }
          }
          .onAppear { draft = document.article.summary ?? "" }
      }
    }
  }
#endif
