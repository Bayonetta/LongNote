import Foundation

/// The kind of a block inside the article body.
///
/// - Note: `.title` is an in-body main heading (H1), distinct from the article's
///   own `Article.title` metadata field edited at the top of the screen.
public enum ParagraphKind: String, Codable, Sendable, CaseIterable, Hashable {
  /// Main heading (H1) used inside the body.
  case title
  /// Sub-heading (H2) used inside the body.
  case header
  /// Regular body text.
  case body
  /// Block quote, rendered with a vertical bar on the leading edge.
  case quote
  /// A list item. Consecutive list paragraphs form a visual run; the last item
  /// of each run carries extra bottom spacing (see `Paragraph.isLastInList`).
  case list
  /// An image with an optional caption.
  case image
  /// A horizontal divider.
  case divider

  /// Whether this kind is an editable text block (not an image or divider).
  public var isTextKind: Bool {
    switch self {
    case .title, .header, .body, .quote, .list: true
    case .image, .divider: false
    }
  }

  /// Kinds a user can pick from the paragraph-style control.
  ///
  /// Quote and list are deliberately absent: both have their own dedicated
  /// button on the compose bar, so repeating them here only duplicates the
  /// toolbar.
  public static let styleKinds: [ParagraphKind] = [.title, .header, .body]
}
