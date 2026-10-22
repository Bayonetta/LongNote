#if canImport(UIKit)
  import SwiftUI
  import UIKit

  /// Full-screen preview of a rendered long image.
  ///
  /// The image is laid out at the screen's width — so a tall article scrolls
  /// vertically and never sideways — and zooms on pinch or double-tap, like the
  /// Photos app. Zooming out again restores the width-fitted view.
  public struct LongImagePreview: UIViewRepresentable {
    public var image: UIImage

    public init(image: UIImage) {
      self.image = image
    }

    public func makeCoordinator() -> Coordinator {
      Coordinator()
    }

    public func makeUIView(context: Context) -> UIScrollView {
      let scrollView = UIScrollView()
      scrollView.minimumZoomScale = 1
      scrollView.maximumZoomScale = 4
      scrollView.bouncesZoom = true
      scrollView.showsVerticalScrollIndicator = false
      scrollView.showsHorizontalScrollIndicator = false
      scrollView.backgroundColor = UIColor(Color(.systemBackground))
      scrollView.contentInsetAdjustmentBehavior = .never
      scrollView.delegate = context.coordinator

      let imageView = UIImageView(image: image)
      // The frame always matches the image's aspect ratio, so no letterboxing.
      imageView.contentMode = .scaleToFill
      imageView.isUserInteractionEnabled = true
      scrollView.addSubview(imageView)
      context.coordinator.imageView = imageView

      let doubleTap = UITapGestureRecognizer(
        target: context.coordinator, action: #selector(Coordinator.doubleTap(_:)))
      doubleTap.numberOfTapsRequired = 2
      scrollView.addGestureRecognizer(doubleTap)

      layoutImage(in: scrollView)
      return scrollView
    }

    public func updateUIView(_ scrollView: UIScrollView, context: Context) {
      // Bounds change on rotation / size class change; re-fit the image, but
      // only while not zoomed — the scroll view owns the frame while zooming.
      if scrollView.zoomScale <= scrollView.minimumZoomScale {
        layoutImage(in: scrollView)
      }
    }

    /// Fits the image to the scroll view's width and sizes the content.
    private func layoutImage(in scrollView: UIScrollView) {
      guard let imageView = scrollView.subviews.compactMap({ $0 as? UIImageView }).first else {
        return
      }
      let width = scrollView.bounds.width
      guard width > 0, image.size.width > 0 else { return }

      let height = width * image.size.height / image.size.width
      imageView.frame = CGRect(x: 0, y: 0, width: width, height: height)
      scrollView.contentSize = CGSize(width: width, height: height)
    }

    // MARK: - Coordinator

    public final class Coordinator: NSObject, UIScrollViewDelegate {
      var imageView: UIImageView?

      public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
      }

      public func scrollViewDidZoom(_ scrollView: UIScrollView) {
        // Centre the image on the axis that is narrower than the viewport.
        let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width) / 2, 0)
        let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) / 2, 0)
        imageView?.center = CGPoint(
          x: scrollView.contentSize.width / 2 + offsetX,
          y: scrollView.contentSize.height / 2 + offsetY
        )
      }

      @objc public func doubleTap(_ gesture: UITapGestureRecognizer) {
        guard let scrollView = gesture.view as? UIScrollView else { return }
        if scrollView.zoomScale > scrollView.minimumZoomScale {
          scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
          return
        }
        // Zoom around the tapped point, like Photos.
        let point = gesture.location(in: imageView)
        let scale: CGFloat = 2.5
        let size = scrollView.bounds.size
        let rect = CGRect(
          x: point.x - size.width / scale / 2,
          y: point.y - size.height / scale / 2,
          width: size.width / scale,
          height: size.height / scale
        )
        scrollView.zoom(to: rect, animated: true)
      }
    }
  }
#endif
