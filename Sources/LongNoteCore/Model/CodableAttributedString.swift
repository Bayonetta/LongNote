import Foundation

/// A lossless, portable `Codable` wrapper around `NSAttributedString`.
///
/// **Storage format (v2).** Styling is stored as *semantic runs* — plain text
/// plus bold/italic/strikethrough/colour/link — instead of an opaque keyed
/// archive:
///
/// ```json
/// "text": { "runs": [ { "text": "…" },
///                     { "text": "bold", "bold": true },
///                     { "text": "link", "link": "https://…" } ] }
/// ```
///
/// Attribute-free text is still written as `{ "string": "…" }`, which keeps
/// simple documents tiny. Documents written by v1 (a base64 `NSKeyedArchive`
/// blob) are still readable — they decode and are rewritten as runs on the next
/// save.
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

  /// Build from semantic runs. Used by the decoder and by tests.
  public init(runs: [TextRun]) {
    self.uiText = Self.makeAttributed(runs)
  }

  /// Rebuilds an attributed string from runs, applying each run's own styling
  /// only (block typography is added later by `styledText(_:)`).
  private static func makeAttributed(_ runs: [TextRun]) -> NSAttributedString {
    let result = NSMutableAttributedString()
    for run in runs {
      PlatformRichText.append(run, to: result)
    }
    return result
  }

  public var string: String {
    uiText.string
  }

  public var isEmpty: Bool {
    uiText.length == 0
  }

  // MARK: Semantic runs

  /// The paragraph's styling as semantic runs. Always returns at least one run
  /// for non-empty text; adjacent runs that only differ because the platform
  /// split an attribute range are coalesced.
  public var runs: [TextRun] {
    guard uiText.length > 0 else { return [] }
    var runs: [TextRun] = []
    uiText.enumerateAttributes(in: NSRange(location: 0, length: uiText.length)) {
      attributes, range, _ in
      let style = PlatformRichText.style(from: attributes)
      let text = (uiText.string as NSString).substring(with: range)
      let run = TextRun(
        text: text,
        bold: style.bold,
        italic: style.italic,
        strike: style.strike,
        color: style.color,
        link: style.link
      )
      if let last = runs.last, last.hasSameStyle(as: run) {
        runs[runs.count - 1].text += run.text
      } else {
        runs.append(run)
      }
    }
    return runs
  }

  /// True when the text carries no styling at all (a single plain run).
  public var isPlainText: Bool {
    let all = runs
    return all.count <= 1 && (all.first?.isPlain ?? true)
  }

  /// Semantic equality: the text plus its run styling.
  ///
  /// Point sizes and platform font/colour objects are not part of the document
  /// model, so two values that differ only by those compare equal — a document
  /// written by the editor and the same document re-read from disk must be `==`.
  public static func == (lhs: CodableAttributedString, rhs: CodableAttributedString) -> Bool {
    lhs.string == rhs.string && lhs.runs == rhs.runs
  }

  // MARK: Codable

  private enum CodingKeys: String, CodingKey {
    case string
    case runs
    /// v1 payload: a keyed archive of the whole attributed string.
    case archive
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    // v2: attribute-free text.
    if let plain = try container.decodeIfPresent(String.self, forKey: .string) {
      self.uiText = NSAttributedString(string: plain)
      return
    }

    // v2: semantic runs.
    if let runs = try container.decodeIfPresent([TextRun].self, forKey: .runs) {
      self.uiText = Self.makeAttributed(runs)
      return
    }

    // v1: keyed archive.
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
      try container.encode(runs, forKey: .runs)
    }
  }
}
