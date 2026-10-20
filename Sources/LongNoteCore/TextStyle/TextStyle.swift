import Foundation

/// Layout & typography constants shared by the editor and the exported long image.
///
/// Fonts and colors are resolved per-platform (a `UIFont`/`UIColor` in the editor,
/// a SwiftUI `Color` in the renderer) from these numbers, so both views stay
/// visually identical. This mirrors the original `kFontSize*` and
/// `WBNoteColorManager` constants without tying them to UIKit.
public enum TextStyle {
  // MARK: Font sizes (points)

  /// The article title field at the top of the screen.
  public static let articleTitleFontSize: CGFloat = 26
  /// In-body main heading (H1).
  public static let heading1FontSize: CGFloat = 22
  /// In-body sub-heading (H2).
  public static let heading2FontSize: CGFloat = 19
  /// Regular body text.
  public static let bodyFontSize: CGFloat = 16
  /// Block quote text.
  public static let quoteFontSize: CGFloat = 15
  /// List item text.
  public static let listFontSize: CGFloat = 16
  /// Image caption.
  public static let captionFontSize: CGFloat = 13
  /// Article date line and the export watermark.
  public static let metaFontSize: CGFloat = 12

  // MARK: Spacing (points)

  /// Horizontal padding inside the editor for text paragraphs.
  public static let editorHorizontalInset: CGFloat = 16
  /// Vertical gap between two regular paragraphs.
  public static let paragraphSpacing: CGFloat = 14
  /// Extra bottom gap after the last item of a list run.
  public static let listLastSpacing: CGFloat = 26
  /// Gap above/below dividers and image blocks.
  public static let blockSpacing: CGFloat = 18
  /// Horizontal inset of a divider line.
  public static let dividerInset: CGFloat = 32
  /// Quote bar width.
  public static let quoteBarWidth: CGFloat = 3

  // MARK: Colors (RGBA in 0...1)

  public static let textColor = RGBColor(red: 0.13, green: 0.13, blue: 0.15, alpha: 1)
  public static let secondaryTextColor = RGBColor(red: 0.55, green: 0.55, blue: 0.58, alpha: 1)
  public static let placeholderColor = RGBColor(red: 0.78, green: 0.78, blue: 0.80, alpha: 1)
  public static let dividerColor = RGBColor(red: 0.89, green: 0.89, blue: 0.90, alpha: 1)
  public static let quoteBarColor = RGBColor(red: 0.85, green: 0.85, blue: 0.87, alpha: 1)
  public static let summaryBackgroundColor = RGBColor(red: 0.97, green: 0.97, blue: 0.98, alpha: 1)
  public static let watermarkColor = RGBColor(red: 0.60, green: 0.60, blue: 0.62, alpha: 1)
  public static let accentColor = RGBColor(red: 0.16, green: 0.50, blue: 0.97, alpha: 1)
  public static let linkColor = RGBColor(red: 0.16, green: 0.50, blue: 0.97, alpha: 1)

  /// A pure RGBA color, platform-neutral so both UIKit and SwiftUI can build
  /// their native color from the same numbers.
  public struct RGBColor: Codable, Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double) {
      self.red = red
      self.green = green
      self.blue = blue
      self.alpha = alpha
    }

    /// Build from a 0xRRGGBB hex value (e.g. `0x2143F0`).
    public init(hex: UInt32, alpha: Double = 1) {
      self.red = Double((hex >> 16) & 0xFF) / 255
      self.green = Double((hex >> 8) & 0xFF) / 255
      self.blue = Double(hex & 0xFF) / 255
      self.alpha = alpha
    }
  }
}
