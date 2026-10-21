#if canImport(UIKit)
  import SwiftUI
  import UIKit
  import LongNoteCore

  /// Non-interactive, fixed-width render of an article used for long-image export.
  /// Mirrors the editor's visual language (fonts, colors, quote bars, list bullets)
  /// so the exported image matches what the user wrote.
  ///
  /// The view is sliceable (`paragraphRange` + `includeHeader`/`includeFooter`) so
  /// very long articles can be rendered tile-by-tile with bounded memory.
  public struct ArticleRenderView: View {
    public var article: Article
    /// Resolves a stored image file name to a `UIImage`.
    public var imageLoader: (String) -> UIImage?
    public var width: CGFloat
    /// Paragraph slice to render; nil = the whole body.
    public var paragraphRange: Range<Int>?
    public var includeHeader: Bool
    public var includeFooter: Bool

    public init(
      article: Article,
      imageLoader: @escaping (String) -> UIImage?,
      width: CGFloat,
      paragraphRange: Range<Int>? = nil,
      includeHeader: Bool = true,
      includeFooter: Bool = true
    ) {
      self.article = article
      self.imageLoader = imageLoader
      self.width = width
      self.paragraphRange = paragraphRange
      self.includeHeader = includeHeader
      self.includeFooter = includeFooter
    }

    private var paragraphs: [Paragraph] {
      guard let range = paragraphRange else { return article.paragraphs }
      let clamped = range.clamped(to: article.paragraphs.indices)
      return Array(article.paragraphs[clamped])
    }

    public var body: some View {
      VStack(spacing: 0) {
        if includeHeader {
          header
        }
        ForEach(paragraphs) { paragraph in
          renderParagraph(paragraph)
        }
        if includeFooter {
          footer
        }
      }
      .frame(width: width)
      .background(Color.white)
    }

    // MARK: - Header

    private var header: some View {
      VStack(spacing: 0) {
        if let cover = article.cover, let image = imageLoader(cover.fileName) {
          Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: width, height: width * 9 / 16)
            .clipped()
        }

        VStack(alignment: .leading, spacing: 10) {
          if !article.title.isEmpty {
            Text(article.title)
              .font(.system(size: TextStyle.articleTitleFontSize, weight: .bold))
              .foregroundStyle(TextStyle.textColor.color)
              .lineSpacing(4)
          }

          Text(dateString)
            .font(.system(size: TextStyle.metaFontSize))
            .foregroundStyle(TextStyle.secondaryTextColor.color)

          if let summary = article.summary, !summary.isEmpty {
            Text(summary)
              .font(.system(size: TextStyle.bodyFontSize))
              .foregroundStyle(TextStyle.secondaryTextColor.color)
              .padding(12)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(TextStyle.summaryBackgroundColor.color)
              .clipShape(RoundedRectangle(cornerRadius: 6))
          }
        }
        .padding(.horizontal, TextStyle.editorHorizontalInset)
        .padding(.vertical, 16)
      }
    }

    private var dateString: String {
      Self.dateFormatter.string(from: article.updatedAt)
    }

    private static let dateFormatter: DateFormatter = {
      let formatter = DateFormatter()
      formatter.locale = Locale(identifier: "zh_CN")
      formatter.dateFormat = "MMM d, yyyy"
      return formatter
    }()

    // MARK: - Paragraphs

    @ViewBuilder
    private func renderParagraph(_ paragraph: Paragraph) -> some View {
      switch paragraph.kind {
      case .image:
        renderImage(paragraph)
      case .divider:
        Rectangle()
          .fill(TextStyle.dividerColor.color)
          .frame(height: 1)
          .padding(.horizontal, TextStyle.dividerInset)
          .padding(.vertical, TextStyle.blockSpacing)
      case .quote:
        HStack(alignment: .top, spacing: 10) {
          RoundedRectangle(cornerRadius: TextStyle.quoteBarWidth / 2)
            .fill(TextStyle.quoteBarColor.color)
            .frame(width: TextStyle.quoteBarWidth)
          Text(renderText(for: paragraph))
            .lineSpacing(4)
        }
        .padding(.horizontal, TextStyle.editorHorizontalInset)
        .padding(.vertical, spacing(for: paragraph))
      case .list:
        HStack(alignment: .top, spacing: 10) {
          Text("•")
            .font(.system(size: TextStyle.listFontSize, weight: .medium))
            .frame(width: 16)
          Text(renderText(for: paragraph))
            .lineSpacing(4)
        }
        .padding(.horizontal, TextStyle.editorHorizontalInset)
        .padding(.vertical, spacing(for: paragraph))
      default:
        Text(renderText(for: paragraph))
          .lineSpacing(4)
          .padding(.horizontal, TextStyle.editorHorizontalInset)
          .padding(.vertical, spacing(for: paragraph))
      }
    }

    @ViewBuilder
    private func renderImage(_ paragraph: Paragraph) -> some View {
      VStack(spacing: 6) {
        if let fileName = paragraph.image?.fileName, let image = imageLoader(fileName) {
          Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
        }
        if let caption = paragraph.image?.caption, !caption.isEmpty {
          Text(caption)
            .font(.system(size: TextStyle.captionFontSize))
            .foregroundStyle(TextStyle.secondaryTextColor.color)
            .multilineTextAlignment(.center)
        }
      }
      .frame(maxWidth: .infinity)
      .padding(.horizontal, TextStyle.editorHorizontalInset)
      .padding(.vertical, TextStyle.blockSpacing)
    }

    private func spacing(for paragraph: Paragraph) -> CGFloat {
      if paragraph.kind == .list, paragraph.isLastInList {
        return TextStyle.listLastSpacing / 2
      }
      return TextStyle.paragraphSpacing / 2
    }

    /// Renders the paragraph's rich text with the block's typography applied
    /// (shared with the editor through `styledText(_:)`, so both agree).
    private func renderText(for paragraph: Paragraph) -> AttributedString {
      paragraph.text.styledText(paragraph.kind).swiftUI
    }

    // MARK: - Footer

    private var footer: some View {
      VStack(spacing: 12) {
        Rectangle()
          .fill(TextStyle.dividerColor.color)
          .frame(height: 1)
          .padding(.horizontal, TextStyle.dividerInset)
        Text("— Made with LongNote —")
          .font(.system(size: TextStyle.metaFontSize))
          .foregroundStyle(TextStyle.watermarkColor.color)
      }
      .padding(.vertical, 16)
    }
  }
#endif
