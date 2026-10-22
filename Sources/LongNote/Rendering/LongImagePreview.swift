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

    public func makeUIView(context: Context) -> ZoomableImageScrollView {
      let scrollView = ZoomableImageScrollView()
      scrollView.minimumZoomScale = 1
      scrollView.maximumZoomScale = 4
      scrollView.bouncesZoom = true
      scrollView.showsVerticalScrollIndicator = false
      scrollView.showsHorizontalScrollIndicator = false
      scrollView.backgroundColor = UIColor(Color(.systemBackground))
      scrollView.contentInsetAdjustmentBehavior = .never
      scrollView.delegate = context.coordinator
      scrollView.apply(image)

      let doubleTap = UITapGestureRecognizer(
        target: context.coordinator, action: #selector(Coordinator.doubleTap(_:)))
      doubleTap.numberOfTapsRequired = 2
      scrollView.addGestureRecognizer(doubleTap)
      return scrollView
    }

    public func updateUIView(_ scrollView: ZoomableImageScrollView, context: Context) {
      scrollView.apply(image)
    }

    // MARK: - Coordinator

    public final class Coordinator: NSObject, UIScrollViewDelegate {
      public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        (scrollView as? ZoomableImageScrollView)?.imageView
      }

      public func scrollViewDidZoom(_ scrollView: UIScrollView) {
        // Centre the image on the axis that is narrower than the viewport.
        let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width) / 2, 0)
        let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) / 2, 0)
        (scrollView as? ZoomableImageScrollView)?.imageView.center = CGPoint(
          x: scrollView.contentSize.width / 2 + offsetX,
          y: scrollView.contentSize.height / 2 + offsetY
        )
      }

      @objc public func doubleTap(_ gesture: UITapGestureRecognizer) {
        guard let scrollView = gesture.view as? ZoomableImageScrollView else { return }
        if scrollView.zoomScale > scrollView.minimumZoomScale {
          scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
          return
        }
        // Zoom around the tapped point, like Photos.
        let point = gesture.location(in: scrollView.imageView)
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

  /// A `UIScrollView` that keeps its image fitted to its own width.
  ///
  /// Fitting happens in `layoutSubviews` rather than from the representable's
  /// `updateUIView`: on the first pass the bounds are still zero, and relying on
  /// a later callback left the image at its natural (much wider) size.
  public final class ZoomableImageScrollView: UIScrollView {
    public let imageView = UIImageView()

    /// height / width of the current image.
    private var imageAspect: CGFloat = 1

    public override init(frame: CGRect) {
      super.init(frame: frame)
      // The frame always matches the image's aspect ratio, so no letterboxing.
      imageView.contentMode = .scaleToFill
      imageView.isUserInteractionEnabled = true
      addSubview(imageView)
    }

    public required init?(coder: NSCoder) {
      fatalError("ZoomableImageScrollView is code-only")
    }

    public override func layoutSubviews() {
      super.layoutSubviews()
      fitImage()
    }

    /// Sets the image and re-fits it.
    public func apply(_ image: UIImage) {
      imageView.image = image
      imageAspect = image.size.height / max(image.size.width, 1)
      fitImage()
    }

    /// Sizes the image to the scroll view's width and sets the content size.
    /// Ignored while zoomed — the scroll view owns the frame then.
    public func fitImage() {
      guard zoomScale <= minimumZoomScale, bounds.width > 0, imageAspect > 0 else { return }
      let height = bounds.width * imageAspect
      imageView.frame = CGRect(x: 0, y: 0, width: bounds.width, height: height)
      contentSize = CGSize(width: bounds.width, height: height)
    }
  }
#endif
