#if canImport(UIKit)
  import SwiftUI
  import UIKit
  import Photos
  import LongNoteCore

  /// Turns an `Article` into a long image using SwiftUI's `ImageRenderer`.
  ///
  /// Memory is the real risk with long-form export (30k characters can be tens of
  /// thousands of points tall). The strategy:
  /// - content shorter than `maxSingleHeight` is rendered in one shot;
  /// - anything longer is rendered **in tiles** (`renderTiles`) with bounded
  ///   per-tile memory, then stitched into a single image when the result fits
  ///   under the pixel-height cap; otherwise the caller is expected to present the
  ///   tiles as a set (see the demo app).
  @MainActor
  public enum ArticleImageRenderer {

    public struct Configuration: Sendable {
      /// Export width in points.
      public var width: CGFloat
      /// Raster scale (2 = @2x).
      public var scale: CGFloat
      /// Content up to this height (points) renders in a single pass.
      public var maxSingleHeight: CGFloat
      /// Per-tile target height (points). One paragraph may exceed this.
      public var maxTileHeight: CGFloat

      public init(
        width: CGFloat = 750, scale: CGFloat = 2, maxSingleHeight: CGFloat = 5000,
        maxTileHeight: CGFloat = 3000
      ) {
        self.width = width
        self.scale = scale
        self.maxSingleHeight = maxSingleHeight
        self.maxTileHeight = maxTileHeight
      }
    }

    /// Render the article to a single image. Returns nil when the content is so
    /// tall that a single image can't be held in memory — use `renderTiles` then.
    public static func render(
      _ article: Article,
      imageLoader: @escaping (String) -> UIImage?,
      configuration: Configuration = Configuration()
    ) async -> UIImage? {
      let total = measureSliceHeight(
        article,
        imageLoader: imageLoader,
        width: configuration.width,
        paragraphRange: article.paragraphs.indices,
        includeHeader: true,
        includeFooter: true
      )

      if total <= configuration.maxSingleHeight {
        return renderSlice(
          article,
          imageLoader: imageLoader,
          configuration: configuration,
          paragraphRange: nil,
          includeHeader: true,
          includeFooter: true
        )
      }

      let tiles = renderTiles(article, imageLoader: imageLoader, configuration: configuration)
      return stitch(tiles)
    }

    /// Render the article as a list of vertically-adjacent tiles, each with a
    /// bounded height. Suitable for very long articles and for sharing as a set.
    public static func renderTiles(
      _ article: Article,
      imageLoader: @escaping (String) -> UIImage?,
      configuration: Configuration = Configuration()
    ) -> [UIImage] {
      guard !article.paragraphs.isEmpty else {
        return []
      }

      let ranges = tileRanges(
        article,
        imageLoader: imageLoader,
        width: configuration.width,
        maxTileHeight: configuration.maxTileHeight
      )

      return ranges.enumerated().compactMap { index, range in
        renderSlice(
          article,
          imageLoader: imageLoader,
          configuration: configuration,
          paragraphRange: range,
          includeHeader: index == 0,
          includeFooter: index == ranges.count - 1
        )
      }
    }

    // MARK: - Rendering

    private static func renderSlice(
      _ article: Article,
      imageLoader: @escaping (String) -> UIImage?,
      configuration: Configuration,
      paragraphRange: Range<Int>?,
      includeHeader: Bool,
      includeFooter: Bool
    ) -> UIImage? {
      let view = ArticleRenderView(
        article: article,
        imageLoader: imageLoader,
        width: configuration.width,
        paragraphRange: paragraphRange,
        includeHeader: includeHeader,
        includeFooter: includeFooter
      )
      let renderer = ImageRenderer(content: view)
      renderer.scale = configuration.scale
      renderer.proposedSize = ProposedViewSize(width: configuration.width, height: nil)
      return renderer.uiImage
    }

    // MARK: - Tiling

    /// Greedily split paragraphs into contiguous ranges that each measure at most
    /// `maxTileHeight` (a single oversized paragraph still gets its own tile).
    private static func tileRanges(
      _ article: Article,
      imageLoader: @escaping (String) -> UIImage?,
      width: CGFloat,
      maxTileHeight: CGFloat
    ) -> [Range<Int>] {
      let count = article.paragraphs.count
      var ranges: [Range<Int>] = []
      var start = 0
      while start < count {
        var end = start + 1
        var lastGoodEnd = end
        while end <= count {
          let height = measureSliceHeight(
            article,
            imageLoader: imageLoader,
            width: width,
            paragraphRange: start..<end,
            includeHeader: start == 0,
            includeFooter: false
          )
          if height <= maxTileHeight {
            lastGoodEnd = end
            end += 1
          } else {
            break
          }
        }
        ranges.append(start..<lastGoodEnd)
        start = lastGoodEnd
      }
      return ranges
    }

    // MARK: - Measurement

    private static func measureSliceHeight(
      _ article: Article,
      imageLoader: @escaping (String) -> UIImage?,
      width: CGFloat,
      paragraphRange: Range<Int>,
      includeHeader: Bool,
      includeFooter: Bool
    ) -> CGFloat {
      let view = ArticleRenderView(
        article: article,
        imageLoader: imageLoader,
        width: width,
        paragraphRange: paragraphRange,
        includeHeader: includeHeader,
        includeFooter: includeFooter
      )
      .fixedSize(horizontal: false, vertical: true)

      let host = UIHostingController(rootView: view)
      return host.view.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
    }

    // MARK: - Stitching

    /// Vertically join tiles into one image. Returns nil when the resulting pixel
    /// height would be too large for a single `UIImage` (bounds render memory).
    private static func stitch(_ tiles: [UIImage]) -> UIImage? {
      guard let first = tiles.first, !tiles.isEmpty else { return nil }
      let totalHeight = tiles.reduce(0) { $0 + $1.size.height }
      let pixelHeight = totalHeight * first.scale
      guard pixelHeight <= 32_000 else { return nil }

      let format = UIGraphicsImageRendererFormat()
      format.scale = first.scale
      let renderer = UIGraphicsImageRenderer(
        size: CGSize(width: first.size.width, height: totalHeight),
        format: format
      )
      return renderer.image { _ in
        var y: CGFloat = 0
        for tile in tiles {
          tile.draw(at: CGPoint(x: 0, y: y))
          y += tile.size.height
        }
      }
    }
  }

  extension UIImage {
    /// Errors surfaced by `saveToPhotoLibrary()`.
    public enum PhotoSaveError: LocalizedError {
      case permissionDenied

      public var errorDescription: String? {
        switch self {
        case .permissionDenied: return "Photo library access is denied — please allow it in Settings"
        }
      }
    }

    /// Request `.addOnly` photo-library access and save the image.
    public func saveToPhotoLibrary() async throws {
      let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
      guard status == .authorized || status == .limited else {
        throw PhotoSaveError.permissionDenied
      }
      try await PHPhotoLibrary.shared().performChanges {
        PHAssetChangeRequest.creationRequestForAsset(from: self)
      }
    }
  }
#endif
