import Foundation

/// Persistence contract for article documents.
///
/// The library ships with `FileArticleStore` (one directory per article) but the
/// protocol is deliberately minimal so a host app can back the drafts with its
/// own storage (Core Data, SwiftData, a server, ...) without touching the editor.
public protocol ArticleStore: Sendable {
  /// All saved articles, newest-updated first.
  func loadAll() throws -> [Article]
  /// The article with `id`, or nil when it does not exist.
  func load(_ id: UUID) throws -> Article?
  /// Create or overwrite `article`.
  func save(_ article: Article) throws
  /// Permanently delete the article with `id` (including its images).
  func delete(_ id: UUID) throws

  // MARK: Image payloads

  /// Absolute URL that resolves an image `fileName` referenced by article `id`.
  func imageURL(for id: UUID, fileName: String) -> URL
  /// Persist image data into the article's image storage. Returns the URL written.
  @discardableResult
  func saveImage(_ data: Data, for id: UUID, fileName: String) throws -> URL
  /// Load image data for a stored file name, if present.
  func loadImage(_ fileName: String, for id: UUID) throws -> Data?
}
