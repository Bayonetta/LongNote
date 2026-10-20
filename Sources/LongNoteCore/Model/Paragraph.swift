import Foundation

/// One block in the article body.
///
/// The `id` is stable for the lifetime of the paragraph and is used for
/// identity (`ForEach`), focus tracking and scroll anchoring. Text blocks carry
/// their rich text in `text`; the image kind carries an image payload instead.
public struct Paragraph: Identifiable, Codable, Equatable, Sendable {
  public var id: UUID
  public var kind: ParagraphKind
  /// Rich text content, serialized losslessly via `CodableAttributedString`
  /// (fonts, colors and links survive a save/load round trip).
  public var text: CodableAttributedString
  /// Image paragraph payload. Present only when `kind == .image`.
  public var image: ParagraphImage?
  /// List paragraphs: true when this is the last item of a consecutive list run,
  /// which controls the bottom spacing. `ParagraphMutation.normalize(_:)` keeps
  /// this flag consistent after every edit.
  public var isLastInList: Bool

  public init(
    id: UUID = UUID(),
    kind: ParagraphKind = .body,
    text: CodableAttributedString = CodableAttributedString(),
    image: ParagraphImage? = nil,
    isLastInList: Bool = false
  ) {
    self.id = id
    self.kind = kind
    self.text = text
    self.image = image
    self.isLastInList = isLastInList
  }

  /// A blank text paragraph of the given kind.
  public static func empty(_ kind: ParagraphKind = .body) -> Paragraph {
    Paragraph(kind: kind)
  }

  public var isEmpty: Bool {
    text.isEmpty
  }
}
