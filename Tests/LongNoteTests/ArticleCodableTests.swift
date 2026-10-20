import Foundation
import XCTest

@testable import LongNoteCore

/// Round-trip of a full `Article` document (metadata + paragraphs) through the
/// same JSON codec `FileArticleStore` uses.
final class ArticleCodableTests: XCTestCase {

  func testFullDocumentRoundTrip() throws {
    let richText = NSMutableAttributedString(string: "First body paragraph")
    richText.addAttribute(
      NSAttributedString.Key("ln.test.mark"),
      value: NSNumber(value: true),
      range: NSRange(location: 0, length: 2)
    )

    let article = Article(
      title: "My Title",
      summary: "Article summary",
      cover: ArticleImage(fileName: "cover.jpg", width: 1600, height: 900),
      paragraphs: [
        .init(kind: .header, text: CodableAttributedString(string: "A heading")),
        .init(kind: .body, text: CodableAttributedString(richText)),
        .init(kind: .quote, text: CodableAttributedString(string: "Quoted text")),
        .init(kind: .list, text: CodableAttributedString(string: "List item")),
        .init(
          kind: .image,
          image: ParagraphImage(fileName: "a.jpg", width: 1000, height: 600, caption: "Figure caption")),
        .init(kind: .divider),
      ],
      createdAt: Date(timeIntervalSince1970: 1_700_000_000),
      updatedAt: Date(timeIntervalSince1970: 1_700_000_100)
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(article)
    let decoded = try JSONDecoder().decode(Article.self, from: data)

    XCTAssertEqual(decoded, article)
    XCTAssertEqual(decoded.title, "My Title")
    XCTAssertEqual(decoded.summary, "Article summary")
    XCTAssertEqual(decoded.cover?.fileName, "cover.jpg")
    XCTAssertEqual(decoded.paragraphs.count, 6)
    XCTAssertEqual(decoded.paragraphs[4].image?.caption, "Figure caption")
    XCTAssertEqual(decoded.paragraphs[5].kind, .divider)
    // Rich text run survived.
    XCTAssertNotNil(
      decoded.paragraphs[1].text.uiText.attribute(
        NSAttributedString.Key("ln.test.mark"),
        at: 0,
        effectiveRange: nil
      ))
  }

  func testImageCount() {
    var article = Article.empty()
    article.paragraphs = [
      .init(kind: .image, image: ParagraphImage(fileName: "1.jpg")),
      .init(kind: .image, image: ParagraphImage(fileName: "2.jpg")),
      .init(kind: .body, text: CodableAttributedString(string: "text")),
    ]
    XCTAssertEqual(article.imageCount, 2)
  }
}
