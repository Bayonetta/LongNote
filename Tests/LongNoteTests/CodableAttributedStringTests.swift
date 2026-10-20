import Foundation
import XCTest

@testable import LongNoteCore

#if canImport(UIKit)
  import UIKit
#endif

/// Round-trip fidelity of `CodableAttributedString` through `JSONEncoder` /
/// `JSONDecoder` (the path `FileArticleStore` uses).
///
/// The UIKit-specific attributes (bold font, color, link) are exercised on Apple
/// platforms; on Windows/Linux the same archiving path is verified with
/// Foundation-only attributes.
final class CodableAttributedStringTests: XCTestCase {

  func testEmpty() {
    let value = CodableAttributedString()
    XCTAssertTrue(value.isEmpty)
    XCTAssertEqual(value.string, "")
  }

  func testRoundTripPreservesText() throws {
    let value = CodableAttributedString(string: "Hello, LongNote")
    let data = try JSONEncoder().encode(value)
    let decoded = try JSONDecoder().decode(CodableAttributedString.self, from: data)

    XCTAssertEqual(decoded.string, "Hello, LongNote")
    XCTAssertEqual(value, decoded)
  }

  func testRoundTripPreservesAttributes() throws {
    let attr = NSMutableAttributedString(string: "bold color link")

    #if canImport(UIKit)
      attr.addAttribute(
        .font, value: UIFont.boldSystemFont(ofSize: 18), range: NSRange(location: 0, length: 4))
      attr.addAttribute(
        .foregroundColor, value: UIColor.systemRed, range: NSRange(location: 5, length: 5))
      attr.addAttribute(
        .link, value: URL(string: "https://example.com")!, range: NSRange(location: 11, length: 4))
    #else
      // Cross-platform fallback: archive numeric/string attributes.
      attr.addAttribute(
        NSAttributedString.Key("ln.test.num"), value: NSNumber(value: 42),
        range: NSRange(location: 0, length: 4))
      attr.addAttribute(
        NSAttributedString.Key("ln.test.str"), value: NSString("marked"),
        range: NSRange(location: 5, length: 5))
    #endif

    let value = CodableAttributedString(attr)
    let data = try JSONEncoder().encode(value)
    let decoded = try JSONDecoder().decode(CodableAttributedString.self, from: data)

    XCTAssertTrue(value == decoded, "Archived attributes must survive a round trip")

    #if canImport(UIKit)
      let font = decoded.uiText.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
      XCTAssertEqual(font, UIFont.boldSystemFont(ofSize: 18))
      let color = decoded.uiText.attribute(.foregroundColor, at: 6, effectiveRange: nil) as? UIColor
      XCTAssertEqual(color, UIColor.systemRed)
      let link = decoded.uiText.attribute(.link, at: 12, effectiveRange: nil) as? URL
      XCTAssertEqual(link, URL(string: "https://example.com"))
    #else
      let num =
        decoded.uiText.attribute(NSAttributedString.Key("ln.test.num"), at: 0, effectiveRange: nil)
        as? Int
      XCTAssertEqual(num, 42)
    #endif
  }

  func testMultipleRunsSurvive() throws {
    let attr = NSMutableAttributedString(string: "one")
    attr.append(NSAttributedString(string: " two"))
    attr.addAttribute(
      NSAttributedString.Key("ln.test.mark"),
      value: NSNumber(value: 1),
      range: NSRange(location: 0, length: 3)
    )

    let decoded = try JSONDecoder().decode(
      CodableAttributedString.self,
      from: JSONEncoder().encode(CodableAttributedString(attr))
    )

    XCTAssertEqual(decoded.string, "one two")
    XCTAssertNotNil(
      decoded.uiText.attribute(NSAttributedString.Key("ln.test.mark"), at: 1, effectiveRange: nil))
    XCTAssertNil(
      decoded.uiText.attribute(NSAttributedString.Key("ln.test.mark"), at: 5, effectiveRange: nil))
  }
}
