import Foundation

/// Default `ArticleStore`: each article lives in its own directory under a root
/// `Articles/` folder (mirroring the original editor's `resourceDirectory`
/// layout).
///
/// ```
/// Documents/Articles/
///   <article-uuid>/
///     article.json      <- the whole document (JSON-encoded Article)
///     images/
///       <file-name>     <- image data referenced by ParagraphImage.fileName
/// ```
///
/// A JSON document is used so the file is debuggable by hand; the rich-text runs
/// inside it are still lossless because `CodableAttributedString` archives each
/// `NSAttributedString` to a data blob.
public final class FileArticleStore: ArticleStore, @unchecked Sendable {
  public let rootDirectory: URL
  private let fileManager: FileManager
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder

  /// - Parameters:
  ///   - rootDirectory: where the `Articles/` container lives. Defaults to
  ///     `<documents>/Articles`.
  ///   - fileManager: injected for testability.
  public init(rootDirectory: URL? = nil, fileManager: FileManager = .default) {
    self.fileManager = fileManager
    if let rootDirectory {
      self.rootDirectory = rootDirectory
    } else {
      let documents =
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
        ?? fileManager.temporaryDirectory
      self.rootDirectory = documents.appendingPathComponent("Articles", isDirectory: true)
    }

    self.encoder = JSONEncoder()
    // `.deferredToDate` encodes a `Date` as a full-precision Double, so
    // `updatedAt` survives a round trip exactly (ISO-8601 strings truncate to
    // milliseconds and would break equality checks).
    encoder.dateEncodingStrategy = .deferredToDate
    encoder.outputFormatting = [.sortedKeys, .prettyPrinted]

    self.decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .deferredToDate
  }

  // MARK: - Paths

  public func articleDirectory(for id: UUID) -> URL {
    rootDirectory.appendingPathComponent(id.uuidString, isDirectory: true)
  }

  public func imagesDirectory(for id: UUID) -> URL {
    articleDirectory(for: id).appendingPathComponent("images", isDirectory: true)
  }

  /// Absolute URL for an image referenced by a paragraph of the article `id`.
  public func imageURL(for id: UUID, fileName: String) -> URL {
    imagesDirectory(for: id).appendingPathComponent(fileName)
  }

  // MARK: - ArticleStore

  public func loadAll() throws -> [Article] {
    guard
      let entries = try? fileManager.contentsOfDirectory(
        at: rootDirectory,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
      )
    else {
      return []
    }
    var articles: [Article] = []
    for entry in entries {
      let jsonURL = entry.appendingPathComponent("article.json")
      guard fileManager.fileExists(atPath: jsonURL.path) else { continue }
      if let article = try? load(from: jsonURL) {
        articles.append(article)
      }
    }
    return articles.sorted { $0.updatedAt > $1.updatedAt }
  }

  public func load(_ id: UUID) throws -> Article? {
    let jsonURL = articleDirectory(for: id).appendingPathComponent("article.json")
    guard fileManager.fileExists(atPath: jsonURL.path) else { return nil }
    return try load(from: jsonURL)
  }

  public func save(_ article: Article) throws {
    let directory = articleDirectory(for: article.id)
    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    let data = try encoder.encode(article)
    try data.write(to: directory.appendingPathComponent("article.json"), options: [.atomic])
  }

  public func delete(_ id: UUID) throws {
    let directory = articleDirectory(for: id)
    guard fileManager.fileExists(atPath: directory.path) else { return }
    try fileManager.removeItem(at: directory)
  }

  // MARK: - Images

  /// Write image data into the article's `images/` directory. Returns the URL
  /// written, which the caller can inspect if needed.
  @discardableResult
  public func saveImage(_ data: Data, for id: UUID, fileName: String) throws -> URL {
    let directory = imagesDirectory(for: id)
    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appendingPathComponent(fileName)
    try data.write(to: url, options: [.atomic])
    return url
  }

  /// Image data for a stored file name, if it exists.
  public func loadImage(_ fileName: String, for id: UUID) throws -> Data? {
    let url = imageURL(for: id, fileName: fileName)
    guard fileManager.fileExists(atPath: url.path) else { return nil }
    return try Data(contentsOf: url)
  }

  // MARK: - Private

  private func load(from url: URL) throws -> Article {
    let data = try Data(contentsOf: url)
    return try decoder.decode(Article.self, from: data)
  }
}
