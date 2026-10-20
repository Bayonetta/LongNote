import Foundation

/// A lossless `Codable` wrapper around `NSAttributedString`.
///
/// Encoding uses `NSKeyedArchiver`, so every attribute (font, foreground color,
/// link, paragraph style, ...) survives a save/load round trip — something plain
/// text or HTML conversion cannot guarantee.
///
/// The wrapped value is exposed as an immutable snapshot: the editor replaces the
/// whole struct when the text changes rather than mutating in place. It is marked
/// `@unchecked Sendable` because `NSAttributedString` is not `Sendable`, but the
/// editor only reads/mutates it on the main actor.
public struct CodableAttributedString: Codable, Equatable, @unchecked Sendable {
  /// The underlying attributed text. Prefer `string` / `isEmpty` for plain
  /// queries and keep mutations on the main actor.
  public var uiText: NSAttributedString

  public init(_ text: NSAttributedString) {
    self.uiText = text
  }

  public init(string: String) {
    self.uiText = NSAttributedString(string: string)
  }

  public init() {
    // `NSAttributedString(string:)` rather than `NSAttributedString()` so this
    // compiles on Windows/Linux CoreLibsFoundation too.
    self.uiText = NSAttributedString(string: "")
  }

  public var string: String {
    uiText.string
  }

  public var isEmpty: Bool {
    uiText.length == 0
  }

  public static func == (lhs: CodableAttributedString, rhs: CodableAttributedString) -> Bool {
    lhs.uiText.isEqual(to: rhs.uiText)
  }

  // MARK: Codable

  /// Attribute-free strings are stored as plain text (a `string` key) instead of
  /// a keyed archive. That is more compact, keeps the JSON readable, and avoids
  /// CoreLibsFoundation (Windows/Linux) choking on archives that carry no
  /// `NSAttributeInfo` key. Text that carries any attribute is stored as an
  /// archive (the `archive` key) for lossless fidelity.
  private enum CodingKeys: String, CodingKey {
    case string
    case archive
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    if let plain = try container.decodeIfPresent(String.self, forKey: .string) {
      self.uiText = NSAttributedString(string: plain)
      return
    }
    let data = try container.decode(Data.self, forKey: .archive)
    guard
      let decoded = try NSKeyedUnarchiver.unarchivedObject(
        ofClass: NSAttributedString.self,
        from: data
      )
    else {
      throw DecodingError.dataCorruptedError(
        forKey: .archive,
        in: container,
        debugDescription: "Unable to unarchive an NSAttributedString from the stored data."
      )
    }
    self.uiText = decoded
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    if isPlainText {
      try container.encode(uiText.string, forKey: .string)
    } else {
      let data = try NSKeyedArchiver.archivedData(
        withRootObject: uiText,
        requiringSecureCoding: false
      )
      try container.encode(data, forKey: .archive)
    }
  }

  /// True when the text carries no attributes at all (single plain run).
  private var isPlainText: Bool {
    guard uiText.length > 0 else { return true }
    var effectiveRange = NSRange(location: 0, length: 0)
    let attributes = uiText.attributes(at: 0, effectiveRange: &effectiveRange)
    return attributes.isEmpty
      && effectiveRange.location == 0
      && effectiveRange.length == uiText.length
  }
}
