import Foundation
import XCTest

@testable import LongNoteCore

#if canImport(UIKit)
  import UIKit
#elseif canImport(AppKit)
  import AppKit
#endif

/// Round-trip behaviour of `CodableAttributedString` through `JSONEncoder` /
/// `JSONDecoder` (the path `FileArticleStore` uses).
///
/// Since schema v2 the document stores *semantic* styling (bold / italic /
/// strikethrough / colour / link) rather than a keyed archive, so these tests
/// pin that contract: styling survives, point sizes and unknown attributes do
/// not (they are not part of the document model).
final class CodableAttributedStringTests: XCTestCase {

  private func roundTrip(_ value: CodableAttributedString) throws -> CodableAttributedString {
    let data = try JSONEncoder().encode(value)
    return try JSONDecoder().decode(CodableAttributedString.self, from: data)
  }

  #if canImport(UIKit) || canImport(AppKit)
    #if canImport(UIKit)
      private func boldFont(_ size: CGFloat) -> UIFont { .boldSystemFont(ofSize: size) }
      private func redColor() -> UIColor { UIColor(red: 1, green: 0, blue: 0, alpha: 1) }
    #else
      private func boldFont(_ size: CGFloat) -> NSFont { .boldSystemFont(ofSize: size) }
      private func redColor() -> NSColor { NSColor(srgbRed: 1, green: 0, blue: 0, alpha: 1) }
    #endif

    private var redRGB: TextStyle.RGBColor {
      TextStyle.RGBColor(red: 1, green: 0, blue: 0, alpha: 1)
    }
  #endif

  func testEmpty() {
    let value = CodableAttributedString()
    XCTAssertTrue(value.isEmpty)
    XCTAssertEqual(value.string, "")
    XCTAssertTrue(value.runs.isEmpty)
  }

  func testRoundTripPreservesText() throws {
    let value = CodableAttributedString(string: "Hello, LongNote")
    let decoded = try roundTrip(value)

    XCTAssertEqual(decoded.string, "Hello, LongNote")
    XCTAssertEqual(value, decoded)
  }

  #if canImport(UIKit) || canImport(AppKit)
    func testRoundTripPreservesSemanticStyling() throws {
      let attr = NSMutableAttributedString(string: "bold color link")
      attr.addAttribute(.font, value: boldFont(18), range: NSRange(location: 0, length: 4))
      attr.addAttribute(.foregroundColor, value: redColor(), range: NSRange(location: 5, length: 5))
      attr.addAttribute(
        .link, value: URL(string: "https://example.com")!, range: NSRange(location: 11, length: 4))

      let decoded = try roundTrip(CodableAttributedString(attr))
      let runs = decoded.runs

      XCTAssertEqual(decoded.string, "bold color link")
      XCTAssertEqual(runs.count, 5)
      XCTAssertEqual(runs[0].bold, true)
      XCTAssertEqual(runs[2].color, redRGB)
      XCTAssertEqual(runs[4].link, URL(string: "https://example.com"))

      // The platform attributes are rebuilt from the semantics.
      XCTAssertNotNil(decoded.uiText.attribute(.font, at: 0, effectiveRange: nil))
      XCTAssertNotNil(decoded.uiText.attribute(.foregroundColor, at: 6, effectiveRange: nil))
    }

    func testPointSizeIsNotPartOfTheDocument() throws {
      let attr = NSAttributedString(
        string: "big", attributes: [.font: boldFont(28)])
      let decoded = try roundTrip(CodableAttributedString(attr))

      // Bold survives; the 28 pt size does not — typography belongs to the block.
      XCTAssertEqual(decoded.runs.first?.bold, true)
      #if canImport(UIKit)
        let font = decoded.uiText.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
      #else
        let font = decoded.uiText.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
      #endif
      XCTAssertEqual(font?.pointSize, TextStyle.bodyFontSize)
    }

    func testUnknownAttributesAreDropped() throws {
      // Documents carry semantic styling only; arbitrary attributes are not
      // persisted (that was the v1 keyed-archive behaviour).
      let attr = NSMutableAttributedString(string: "marked")
      attr.addAttribute(
        NSAttributedString.Key("ln.test.mark"), value: NSNumber(value: true),
        range: NSRange(location: 0, length: 6))

      let decoded = try roundTrip(CodableAttributedString(attr))

      XCTAssertEqual(decoded.string, "marked")
      XCTAssertNil(
        decoded.uiText.attribute(NSAttributedString.Key("ln.test.mark"), at: 0, effectiveRange: nil))
      XCTAssertTrue(decoded.isPlainText)
    }

    func testMultipleRunsSurvive() throws {
      let attr = NSMutableAttributedString(string: "one")
      attr.append(NSAttributedString(string: " two"))
      attr.addAttribute(.font, value: boldFont(16), range: NSRange(location: 0, length: 3))

      let decoded = try roundTrip(CodableAttributedString(attr))

      XCTAssertEqual(decoded.string, "one two")
      XCTAssertEqual(decoded.runs.count, 2)
      XCTAssertEqual(decoded.runs[0].text, "one")
      XCTAssertEqual(decoded.runs[0].bold, true)
      XCTAssertEqual(decoded.runs[1].text, " two")
      XCTAssertNil(decoded.runs[1].bold)
    }
  #endif
}
