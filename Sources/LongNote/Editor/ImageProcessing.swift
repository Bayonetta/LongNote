#if canImport(UIKit)
  import UIKit
  import CoreGraphics

  extension UIImage {
    /// Downsample (never upscale) so the longest edge is at most `maxEdge`
    /// points. Keeps article images memory-friendly — the original app capped
    /// images at ~1000pt wide for the same reason.
    func downsampledTo(maxEdge: CGFloat) -> UIImage {
      let longest = max(size.width, size.height)
      guard longest > maxEdge else { return self }
      let scale = maxEdge / longest
      let newSize = CGSize(width: size.width * scale, height: size.height * scale)
      let renderer = UIGraphicsImageRenderer(size: newSize)
      return renderer.image { _ in
        draw(in: CGRect(origin: .zero, size: newSize))
      }
    }

    /// JPEG data suitable for storage in the article's `images/` directory.
    func jpegDataForStorage(compressionQuality: CGFloat = 0.9) -> Data? {
      jpegData(compressionQuality: compressionQuality)
    }
  }
#endif
