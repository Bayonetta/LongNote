import Foundation

#if canImport(UIKit)
  import UIKit
#elseif canImport(AppKit)
  import AppKit
#endif

/// Platform bridges for `TextStyle.RGBColor`.
///
/// They live in the core so the storage codec (which turns a platform colour
/// into a semantic run and back) can use them, while the iOS UI target keeps
/// only SwiftUI-specific helpers.
#if canImport(UIKit)
  extension TextStyle.RGBColor {
    /// The UIKit colour used by the editor.
    public var uiColor: UIColor {
      UIColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: CGFloat(alpha))
    }

    /// Build from a UIKit colour. Returns nil for colours that cannot be
    /// expressed as RGBA (e.g. pattern colours).
    public init?(uiColor: UIColor) {
      var red: CGFloat = 0
      var green: CGFloat = 0
      var blue: CGFloat = 0
      var alpha: CGFloat = 0
      guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
      self.init(
        red: Double(red), green: Double(green), blue: Double(blue), alpha: Double(alpha))
    }
  }
#elseif canImport(AppKit)
  extension TextStyle.RGBColor {
    /// The sRGB AppKit colour (used by macOS builds and the test target).
    public var nsColor: NSColor {
      NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }

    public init?(nsColor: NSColor) {
      guard let rgb = nsColor.usingColorSpace(.sRGB) else { return nil }
      self.init(
        red: Double(rgb.redComponent),
        green: Double(rgb.greenComponent),
        blue: Double(rgb.blueComponent),
        alpha: Double(rgb.alphaComponent)
      )
    }
  }
#endif
