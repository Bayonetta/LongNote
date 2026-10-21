import XCTest

@testable import LongNoteCore

#if canImport(AppKit)
  import AppKit
#endif

/// Covers the v2 semantic-run storage format: what gets written, what survives a
/// round trip, and that v1 documents (keyed archives) still open.
final class RichTextRunTests: XCTestCase {

  private let encoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return encoder
  }()

  private func jsonObject(_ value: Codable) throws -> [String: Any] {
    let data = try encoder.encode(value)
    return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
  }

  // MARK: - Plain text

  func testPlainTextEncodesAsStringKey() throws {
    let text = CodableAttributedString(string: "Hello world")
    let object = try jsonObject(text)

    XCTAssertEqual(object["string"] as? String, "Hello world")
    XCTAssertNil(object["runs"])
    XCTAssertNil(object["archive"])
  }

  func testPlainTextRoundTrips() throws {
    let text = CodableAttributedString(string: "Hello world")
    let decoded = try JSONDecoder().decode(
      CodableAttributedString.self, from: encoder.encode(text))

    XCTAssertEqual(decoded.string, "Hello world")
    XCTAssertEqual(decoded.runs.count, 1)
    XCTAssertTrue(decoded.runs[0].isPlain)
  }

  func testEmptyTextHasNoRuns() throws {
    let text = CodableAttributedString()
    XCTAssertTrue(text.runs.isEmpty)
    XCTAssertTrue(text.isPlainText)

    let object = try jsonObject(text)
    XCTAssertEqual(object["string"] as? String, "")
  }

  // MARK: - Semantic runs (Apple platforms)

  #if canImport(AppKit)
    private func styledText() -> NSAttributedString {
      let result = NSMutableAttributedString(string: "plain ")
      result.append(
        NSAttributedString(
          string: "bold",
          attributes: [.font: NSFont.boldSystemFont(ofSize: 16)]
        ))
      result.append(NSAttributedString(string: " and "))
      result.append(
        NSAttributedString(
          string: "red link",
          attributes: [
            .foregroundColor: NSColor.red,
            .link: URL(string: "https://example.com")!,
          ]
        ))
      return result
    }

    func testStyledTextEncodesAsRuns() throws {
      let text = CodableAttributedString(styledText())
      let object = try jsonObject(text)

      let runs = try XCTUnwrap(object["runs"] as? [[String: Any]])
      XCTAssertEqual(runs.count, 4)
      XCTAssertEqual(runs[0]["text"] as? String, "plain ")
      XCTAssertNil(runs[0]["bold"])
      XCTAssertEqual(runs[1]["text"] as? String, "bold")
      XCTAssertEqual(runs[1]["bold"] as? Bool, true)
      XCTAssertEqual(runs[3]["link"] as? String, "https://example.com")
      XCTAssertNotNil(runs[3]["color"])
      XCTAssertNil(object["archive"])
    }

    func testStyledRunsRoundTrip() throws {
      let original = CodableAttributedString(styledText())
      let decoded = try JSONDecoder().decode(
        CodableAttributedString.self, from: encoder.encode(original))

      XCTAssertEqual(decoded.string, original.string)

      let runs = decoded.runs
      XCTAssertEqual(runs.count, 4)
      XCTAssertEqual(runs[1].bold, true)
      XCTAssertEqual(runs[3].link, URL(string: "https://example.com"))
      XCTAssertEqual(runs[3].color, TextStyle.RGBColor(nsColor: .red))
    }

    func testAdjacentRunsWithSameStyleAreCoalesced() throws {
      // Two separate runs with identical styling (different font instances) —
      // the platform splits them, the model should not.
      let result = NSMutableAttributedString(
        string: "a",
        attributes: [.font: NSFont.systemFont(ofSize: 16)])
      result.append(
        NSAttributedString(
          string: "b",
          attributes: [.font: NSFont.systemFont(ofSize: 16)]
        ))

      let text = CodableAttributedString(result)
      XCTAssertEqual(text.runs.count, 1)
      XCTAssertEqual(text.runs[0].text, "ab")
      XCTAssertTrue(text.isPlainText)
    }

    func testStrikethroughRoundTrip() throws {
      let original = NSAttributedString(
        string: "gone",
        attributes: [.strikethroughStyle: NSUnderlineStyle.single.rawValue])
      let decoded = try JSONDecoder().decode(
        CodableAttributedString.self,
        from: encoder.encode(CodableAttributedString(original))
      )

      XCTAssertEqual(decoded.runs.first?.strike, true)
    }

    func testV1KeyedArchiveStillDecodes() throws {
      let archived = try NSKeyedArchiver.archivedData(
        withRootObject: styledText(), requiringSecureCoding: false)
      let payload = ["archive": archived.base64EncodedString()]
      let json = try JSONSerialization.data(withJSONObject: payload)

      let decoded = try JSONDecoder().decode(CodableAttributedString.self, from: json)
      XCTAssertEqual(decoded.string, styledText().string)
      XCTAssertEqual(decoded.runs.first(where: { $0.text == "bold" })?.bold, true)

      // Re-encoding produces v2 (no archive blob).
      let object = try jsonObject(decoded)
      XCTAssertNil(object["archive"])
      XCTAssertNotNil(object["runs"])
    }
  #endif

  // MARK: - Colours

  func testColourEncodesAsCompactArray() throws {
    let color = TextStyle.RGBColor(red: 0.16, green: 0.5, blue: 0.97, alpha: 1)
    let data = try encoder.encode(color)
    let array = try XCTUnwrap(
      JSONSerialization.jsonObject(with: data) as? [Double])
    XCTAssertEqual(array.count, 4)
    XCTAssertEqual(array[0], 0.16, accuracy: 0.0001)

    let decoded = try JSONDecoder().decode(TextStyle.RGBColor.self, from: data)
    XCTAssertEqual(decoded, color)
  }

  func testColourWithoutAlphaDefaultsToOpaque() throws {
    let json = Data("[0.5, 0.25, 0.75]".utf8)
    let decoded = try JSONDecoder().decode(TextStyle.RGBColor.self, from: json)
    XCTAssertEqual(decoded.alpha, 1)
  }

  // MARK: - Schema version

  func testArticleWithoutSchemaVersionDecodesAsV1() throws {
    let legacy = """
      {
        "id": "\(UUID().uuidString)",
        "title": "Legacy",
        "paragraphs": [],
        "createdAt": 0,
        "updatedAt": 0
      }
      """
    let article = try JSONDecoder().decode(Article.self, from: Data(legacy.utf8))

    XCTAssertEqual(article.schemaVersion, 1)
    XCTAssertEqual(article.migrated().schemaVersion, Article.currentSchemaVersion)
  }

  func testNewArticlesCarryCurrentSchemaVersion() throws {
    let article = Article.empty()
    XCTAssertEqual(article.schemaVersion, Article.currentSchemaVersion)

    let decoded = try JSONDecoder().decode(
      Article.self, from: encoder.encode(article))
    XCTAssertEqual(decoded.schemaVersion, Article.currentSchemaVersion)
  }
}
