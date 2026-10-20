import Foundation

/// Metadata for an image paragraph (an in-body illustration).
///
/// `fileName` is relative to the owning article's `images/` directory; the actual
/// bytes live on disk under that directory (see `FileArticleStore`).
public struct ParagraphImage: Codable, Equatable, Sendable {
  /// File name inside the article's `images/` directory.
  public var fileName: String
  /// Natural pixel size, kept so both the editor and the renderer can lay the
  /// image out with the correct aspect ratio before the data is even loaded.
  public var width: CGFloat
  public var height: CGFloat
  /// Optional user-written caption shown below the image.
  public var caption: String

  public init(fileName: String = "", width: CGFloat = 0, height: CGFloat = 0, caption: String = "")
  {
    self.fileName = fileName
    self.width = width
    self.height = height
    self.caption = caption
  }

  /// `width / height`, defaulting to 16:9 when the size is unknown or invalid.
  public var aspectRatio: CGFloat {
    height > 0 && width > 0 ? width / height : 16.0 / 9.0
  }
}
