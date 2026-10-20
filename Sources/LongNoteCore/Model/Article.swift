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
    updatedAt: Date = Date()
  ) {
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
}
