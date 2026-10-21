import Foundation

/// Layout & typography constants shared by the editor and the exported long image.
///
/// Fonts and colors are resolved per-platform (a `UIFont`/`UIColor` in the editor,
/// a SwiftUI `Color` in the renderer) from these numbers, so both views stay
/// visually identical. This mirrors the original `kFontSize*` and
/// `WBNoteColorManager` constants without tying them to UIKit.
public enum TextStyle {
  // MARK: Font sizes (points)

  // Sizes mirror the original WeicoArticle constants (kFontSize*).

  /// The article title field at the top of the screen.
  public static let articleTitleFontSize: CGFloat = 21
  /// In-body main heading (H1).
  public static let heading1FontSize: CGFloat = 20
  /// In-body sub-heading (H2).
  public static let heading2FontSize: CGFloat = 19
  /// Regular body text.
  public static let bodyFontSize: CGFloat = 18
  /// The summary / lede row.
  public static let summaryFontSize: CGFloat = 17
  /// Block quote text.
  public static let quoteFontSize: CGFloat = 17
  /// List item text.
  public static let listFontSize: CGFloat = 18
  /// Image caption.
  public static let captionFontSize: CGFloat = 13
  /// Article date line and the export watermark.
  public static let metaFontSize: CGFloat = 12

  // MARK: Line spacing (inside one paragraph; original kLineHeight*)

  /// Extra leading between lines of body / heading / list text (the original
  /// stores `NSLineSpacing = 9` on every paragraph).
  public static let lineSpacingText: CGFloat = 9
  /// Extra leading between quote lines (also 9 in the original's archives).
  public static let lineSpacingQuote: CGFloat = 9
  /// Extra leading under an image caption.
  public static let lineSpacingCaption: CGFloat = 5

  // MARK: Spacing (points)

  /// Horizontal padding inside the editor for text paragraphs (original
  /// `kMarginTextLeft` = 15 − 5).
  public static let editorHorizontalInset: CGFloat = 10
  /// Left inset of the quote bar (original `kMarginQuoteLeft` = 20 + 4 + 19 − 5).
  public static let quoteInset: CGFloat = 20
  /// Right inset of quote text (original `kMarginQuoteRight` = 28 − 5).
  public static let quoteRightInset: CGFloat = 23
  /// Quote bar width.
  public static let quoteBarWidth: CGFloat = 4
  /// Gap *below* every paragraph (original `kMarginParagraph` = 30).
  public static let paragraphSpacing: CGFloat = 30
  /// Gap below a list item that is followed by another item (original
  /// `kLineHeightText` = 8).
  public static let listItemSpacing: CGFloat = 8
  /// Gap below the last item of a list run (original `kEdgeInsetsUnorderLast`).
  public static let listLastSpacing: CGFloat = 30
  /// Gap above/below dividers and image blocks.
  public static let blockSpacing: CGFloat = 18
  /// Horizontal inset of a divider line.
  public static let dividerInset: CGFloat = 32

  // MARK: Colors (RGBA in 0...1)

  /// Body text (original `kFontColorText` = white 0.2).
  public static let textColor = RGBColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1)
  /// Block-quote text (the original stores white 0.576).
  public static let quoteTextColor = RGBColor(red: 0.576, green: 0.576, blue: 0.576, alpha: 1)
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
  ///
  /// Encodes as a compact `[r, g, b, a]` array so a run reads as
  /// `{ "text": "…", "color": [0.16, 0.5, 0.97, 1] }` in the document JSON.
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

    // MARK: Codable (compact array form)

    public init(from decoder: Decoder) throws {
      var container = try decoder.unkeyedContainer()
      red = try container.decode(Double.self)
      green = try container.decode(Double.self)
      blue = try container.decode(Double.self)
      alpha = container.isAtEnd ? 1 : try container.decode(Double.self)
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.unkeyedContainer()
      try container.encode(red)
      try container.encode(green)
      try container.encode(blue)
      try container.encode(alpha)
    }
  }
}
