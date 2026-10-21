import Foundation

/// The cover image of an article (16:9 banner at the top of the screen and of
/// the exported long image). `fileName` is relative to the article's `images/`.
public struct ArticleImage: Codable, Equatable, Sendable {
  public var fileName: String
  public var width: CGFloat
  public var height: CGFloat

  public init(fileName: String = "", width: CGFloat = 0, height: CGFloat = 0) {
    self.fileName = fileName
    self.width = width
    self.height = height
  }
}

/// An article document: metadata (title, summary, cover) plus an ordered list of
/// body paragraphs. Everything is `Codable` so the whole document persists as a
/// single JSON file (`FileArticleStore`).
public struct Article: Identifiable, Codable, Equatable, Sendable {
  /// Bumped whenever the on-disk shape changes. v1 stored rich text as a
  /// `NSKeyedArchive` blob; v2 stores semantic runs (see `CodableAttributedString`).
  public static let currentSchemaVersion = 2

  /// The schema this document was written with. Decoding a v1 file (which has
  /// no such key) yields `1`, and `migrated()` brings it up to date.
  public var schemaVersion: Int
  public var id: UUID
  public var title: String
  public var summary: String?
  public var cover: ArticleImage?
  public var paragraphs: [Paragraph]
  public var createdAt: Date
  public var updatedAt: Date

  public init(
    id: UUID = UUID(),
    title: String = "",
    summary: String? = nil,
    cover: ArticleImage? = nil,
    paragraphs: [Paragraph] = [],
    createdAt: Date = Date(),
    updatedAt: Date = Date(),
    schemaVersion: Int = Article.currentSchemaVersion
  ) {
    self.schemaVersion = schemaVersion
    self.id = id
    self.title = title
    self.summary = summary
    self.cover = cover
    self.paragraphs = paragraphs
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  /// A brand-new article with one empty body paragraph ready to type in.
  public static func empty() -> Article {
    Article(paragraphs: [.empty(.body)])
  }

  /// True when the article has no title, no cover and no non-empty paragraphs.
  public var isEmpty: Bool {
    title.isEmpty && cover == nil && paragraphs.allSatisfy(\.isEmpty)
  }

  /// Number of image paragraphs currently in the body (used for the 30-image cap).
  public var imageCount: Int {
    paragraphs.filter { $0.kind == .image }.count
  }

  // MARK: Migration

  /// Brings a decoded document up to `currentSchemaVersion`.
  ///
  /// v1 → v2 needs no structural rewrite: `CodableAttributedString` still reads
  /// keyed archives, and the next save writes semantic runs. Future versions add
  /// their steps here.
  public func migrated() -> Article {
    var copy = self
    copy.schemaVersion = Self.currentSchemaVersion
    return copy
  }

  // MARK: Codable

  private enum CodingKeys: String, CodingKey {
    case schemaVersion
    case id
    case title
    case summary
    case cover
    case paragraphs
    case createdAt
    case updatedAt
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
    id = try container.decode(UUID.self, forKey: .id)
    title = try container.decode(String.self, forKey: .title)
    summary = try container.decodeIfPresent(String.self, forKey: .summary)
    cover = try container.decodeIfPresent(ArticleImage.self, forKey: .cover)
    paragraphs = try container.decode([Paragraph].self, forKey: .paragraphs)
    createdAt = try container.decode(Date.self, forKey: .createdAt)
    updatedAt = try container.decode(Date.self, forKey: .updatedAt)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(schemaVersion, forKey: .schemaVersion)
    try container.encode(id, forKey: .id)
    try container.encode(title, forKey: .title)
    try container.encodeIfPresent(summary, forKey: .summary)
    try container.encodeIfPresent(cover, forKey: .cover)
    try container.encode(paragraphs, forKey: .paragraphs)
    try container.encode(createdAt, forKey: .createdAt)
    try container.encode(updatedAt, forKey: .updatedAt)
  }
}
