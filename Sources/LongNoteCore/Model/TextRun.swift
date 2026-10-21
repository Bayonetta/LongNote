import Foundation

/// One styled run inside a paragraph.
///
/// A run stores *semantic* styling only — bold, italic, strikethrough, an
/// explicit colour and a link. Font sizes and platform font/colour objects are
/// deliberately absent: typography belongs to the paragraph's kind
/// (`ParagraphKind.baseFont`), so the same document renders the same way on any
/// platform, and restyling a block never rewrites its text.
///
/// Encoding omits unset flags, so a plain run serialises as `{"text": "…"}`.
public struct TextRun: Codable, Equatable, Sendable {
  public var text: String
  public var bold: Bool?
  public var italic: Bool?
  public var strike: Bool?
  public var color: TextStyle.RGBColor?
  public var link: URL?

  public init(
    text: String,
    bold: Bool? = nil,
    italic: Bool? = nil,
    strike: Bool? = nil,
    color: TextStyle.RGBColor? = nil,
    link: URL? = nil
  ) {
    self.text = text
    self.bold = bold
    self.italic = italic
    self.strike = strike
    self.color = color
    self.link = link
  }

  /// True when the run carries no styling at all (it inherits the block's look).
  public var isPlain: Bool {
    bold == nil && italic == nil && strike == nil && color == nil && link == nil
  }

  /// True when `other` carries the same styling, ignoring the text itself.
  /// Used to coalesce adjacent runs that only differ by how the platform
  /// happened to split the attribute ranges.
  public func hasSameStyle(as other: TextRun) -> Bool {
    bold == other.bold
      && italic == other.italic
      && strike == other.strike
      && color == other.color
      && link == other.link
  }
}
