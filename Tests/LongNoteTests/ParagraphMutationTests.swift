import Foundation
import XCTest

@testable import LongNoteCore

/// Tests for the pure paragraph-editing algorithms in `ParagraphMutation`.
final class ParagraphMutationTests: XCTestCase {

  // MARK: - Helpers

  private func body(_ text: String) -> Paragraph {
    Paragraph(kind: .body, text: CodableAttributedString(string: text))
  }

  private func list(_ text: String) -> Paragraph {
    var p = Paragraph(kind: .list, text: CodableAttributedString(string: text))
    p.isLastInList = true
    return p
  }

  private func texts(_ paragraphs: [Paragraph]) -> [String] {
    paragraphs.map(\.text.string)
  }

  private func kinds(_ paragraphs: [Paragraph]) -> [ParagraphKind] {
    paragraphs.map(\.kind)
  }

  // MARK: - Split (Return key)

  func testSplitMidParagraph() {
    let p = body("Hello world")
    let result = ParagraphMutation.split([p], id: p.id, at: 5)

    XCTAssertEqual(result.paragraphs.count, 2)
    XCTAssertEqual(texts(result.paragraphs), ["Hello", " world"])
    XCTAssertEqual(result.focusID, result.paragraphs[1].id)
    XCTAssertEqual(result.selection, NSRange(location: 0, length: 0))
    XCTAssertEqual(kinds(result.paragraphs), [.body, .body])
  }

  func testSplitAtEndCreatesEmptyTail() {
    let p = body("Hello")
    let result = ParagraphMutation.split([p], id: p.id, at: 5)

    XCTAssertEqual(result.paragraphs.count, 2)
    XCTAssertEqual(result.paragraphs[0].text.string, "Hello")
    XCTAssertTrue(result.paragraphs[1].isEmpty)
    XCTAssertEqual(result.focusID, result.paragraphs[1].id)
  }

  func testSplitAtStart() {
    let p = body("Hello")
    let result = ParagraphMutation.split([p], id: p.id, at: 0)

    XCTAssertEqual(result.paragraphs.count, 2)
    XCTAssertTrue(result.paragraphs[0].isEmpty)
    XCTAssertEqual(result.paragraphs[1].text.string, "Hello")
  }

  func testSplitClampsOutOfRangeLocation() {
    let p = body("Hello")
    let result = ParagraphMutation.split([p], id: p.id, at: 999)

    XCTAssertEqual(result.paragraphs.count, 2)
    XCTAssertEqual(result.paragraphs[0].text.string, "Hello")
    XCTAssertTrue(result.paragraphs[1].isEmpty)
  }

  func testSplitPreservesAttributesOnTail() {
    // "Hello bold" — mark "bold" (offset 6, length 4).
    let attributed = NSMutableAttributedString(string: "Hello bold")
    attributed.addAttribute(
      NSAttributedString.Key("ln.test.bold"),
      value: NSNumber(value: true),
      range: NSRange(location: 6, length: 4)
    )
    let p = Paragraph(kind: .body, text: CodableAttributedString(attributed))

    let result = ParagraphMutation.split([p], id: p.id, at: 6)
    let head = result.paragraphs[0]
    let tail = result.paragraphs[1]

    XCTAssertEqual(head.text.string, "Hello ")
    XCTAssertEqual(tail.text.string, "bold")
    // The marked run stays on the tail, not the head.
    XCTAssertNotNil(
      tail.text.uiText.attribute(NSAttributedString.Key("ln.test.bold"), at: 1, effectiveRange: nil)
    )
    XCTAssertNil(
      head.text.uiText.attribute(NSAttributedString.Key("ln.test.bold"), at: 0, effectiveRange: nil)
    )
  }

  func testSplitListItemContinuesList() {
    let p = list("one two")
    let result = ParagraphMutation.split([p], id: p.id, at: 3)

    XCTAssertEqual(kinds(result.paragraphs), [.list, .list])
    XCTAssertEqual(texts(result.paragraphs), ["one", " two"])
    // Normalized: only the last item of the run is marked as last.
    XCTAssertFalse(result.paragraphs[0].isLastInList)
    XCTAssertTrue(result.paragraphs[1].isLastInList)
  }

  // MARK: - Merge (backspace at line start)

  func testMergeIntoPrevious() {
    let p0 = body("Hello")
    let p1 = body("World")
    let result = ParagraphMutation.mergeIntoPrevious([p0, p1], id: p1.id)

    XCTAssertEqual(result.paragraphs.count, 1)
    XCTAssertEqual(result.paragraphs[0].text.string, "HelloWorld")
    XCTAssertEqual(result.focusID, p0.id)
    XCTAssertEqual(result.selection, NSRange(location: 5, length: 0))
  }

  func testMergeEmptyParagraphDeletesIt() {
    let p0 = body("Hello")
    let p1 = body("")
    let result = ParagraphMutation.mergeIntoPrevious([p0, p1], id: p1.id)

    XCTAssertEqual(result.paragraphs.count, 1)
    XCTAssertEqual(result.paragraphs[0].text.string, "Hello")
    XCTAssertEqual(result.focusID, p0.id)
    XCTAssertEqual(result.selection, NSRange(location: 5, length: 0))
  }

  func testMergeSkipsAndRemovesDivider() {
    let a = body("A")
    let divider = Paragraph(kind: .divider)
    let b = body("B")
    let result = ParagraphMutation.mergeIntoPrevious([a, divider, b], id: b.id)

    XCTAssertEqual(result.paragraphs.count, 1)
    XCTAssertEqual(result.paragraphs[0].text.string, "AB")
    XCTAssertEqual(result.focusID, a.id)
  }

  func testMergeSkipsAndRemovesImage() {
    let a = body("A")
    let image = Paragraph(kind: .image)
    var imageWithData = image
    imageWithData.image = ParagraphImage(fileName: "pic.jpg", width: 100, height: 50)
    let b = body("B")
    let result = ParagraphMutation.mergeIntoPrevious([a, imageWithData, b], id: b.id)

    XCTAssertEqual(result.paragraphs.count, 1)
    XCTAssertEqual(result.paragraphs[0].text.string, "AB")
    XCTAssertEqual(result.focusID, a.id)
  }

  func testMergeKeepsParagraphWhenOnlyBlocksAbove() {
    let divider = Paragraph(kind: .divider)
    let b = body("B")
    let result = ParagraphMutation.mergeIntoPrevious([divider, b], id: b.id)

    XCTAssertEqual(result.paragraphs.count, 1)
    XCTAssertEqual(result.paragraphs[0].text.string, "B")
    XCTAssertEqual(result.focusID, b.id)
    XCTAssertEqual(result.selection, NSRange(location: 0, length: 0))
  }

  func testMergeFirstParagraphIsNoOp() {
    let p = body("Hello")
    let result = ParagraphMutation.mergeIntoPrevious([p], id: p.id)

    XCTAssertEqual(result.paragraphs, [p])
    XCTAssertEqual(result.focusID, p.id)
    XCTAssertEqual(result.selection, NSRange(location: 0, length: 0))
  }

  // MARK: - Convert kind

  func testConvertToQuote() {
    let p = body("x")
    let result = ParagraphMutation.convert([p], id: p.id, to: .quote)

    XCTAssertEqual(result.paragraphs[0].kind, .quote)
    XCTAssertEqual(result.focusID, p.id)
    XCTAssertNil(result.selection)
  }

  func testConvertToBodyClearsListFlag() {
    let p = list("x")
    let result = ParagraphMutation.convert([p], id: p.id, to: .body)

    XCTAssertEqual(result.paragraphs[0].kind, .body)
    XCTAssertFalse(result.paragraphs[0].isLastInList)
  }

  // MARK: - Return key semantics

  func testReturnOnEmptyListItemCancelsList() {
    let p = list("")
    let result = ParagraphMutation.returnKey([p], id: p.id, location: 0)

    XCTAssertEqual(result.paragraphs.count, 1)
    XCTAssertEqual(result.paragraphs[0].kind, .body)
    XCTAssertEqual(result.focusID, p.id)
  }

  func testReturnOnNonEmptyListItemSplits() {
    let p = list("a b")
    let result = ParagraphMutation.returnKey([p], id: p.id, location: 2)

    XCTAssertEqual(result.paragraphs.count, 2)
    XCTAssertEqual(kinds(result.paragraphs), [.list, .list])
    XCTAssertEqual(result.focusID, result.paragraphs[1].id)
  }

  // MARK: - Multi-line paste

  func testPasteSplitsLinesIntoParagraphs() {
    let p = body("Hello")
    let result = ParagraphMutation.splitPastedText(
      [p], id: p.id,
      range: NSRange(location: 5, length: 0),
      pasted: " World\nFoo Bar"
    )

    XCTAssertEqual(result.paragraphs.count, 2)
    XCTAssertEqual(texts(result.paragraphs), ["Hello World", "Foo Bar"])
    XCTAssertEqual(result.focusID, result.paragraphs[1].id)
    XCTAssertEqual(result.selection, NSRange(location: 7, length: 0))
  }

  func testPasteDropsTrailingEmptyLine() {
    let p = body("a")
    let result = ParagraphMutation.splitPastedText(
      [p], id: p.id,
      range: NSRange(location: 1, length: 0),
      pasted: "b\nc\n"
    )

    XCTAssertEqual(result.paragraphs.count, 2)
    XCTAssertEqual(texts(result.paragraphs), ["ab", "c"])
  }

  func testPasteSingleLineJustReplaces() {
    let p = body("Hello")
    let result = ParagraphMutation.splitPastedText(
      [p], id: p.id,
      range: NSRange(location: 5, length: 0),
      pasted: "!"
    )

    XCTAssertEqual(result.paragraphs.count, 1)
    XCTAssertEqual(result.paragraphs[0].text.string, "Hello!")
    XCTAssertEqual(result.focusID, p.id)
  }

  // MARK: - Block insertion

  func testInsertDividerFocusesLineBelow() {
    let p = body("x")
    let result = ParagraphMutation.insertDivider([p], after: p.id)

    XCTAssertEqual(kinds(result.paragraphs), [.body, .divider, .body])
    XCTAssertTrue(result.paragraphs[2].isEmpty)
    XCTAssertEqual(result.focusID, result.paragraphs[2].id)
  }

  func testInsertDividerReusesExistingTextParagraphBelow() {
    let a = body("A")
    let b = body("B")
    let result = ParagraphMutation.insertDivider([a, b], after: a.id)

    XCTAssertEqual(kinds(result.paragraphs), [.body, .divider, .body])
    XCTAssertEqual(result.paragraphs[2].text.string, "B")
    XCTAssertEqual(result.focusID, b.id)
  }

  func testInsertDividerAddsBodyBeforeImage() {
    let a = body("A")
    var image = Paragraph(kind: .image)
    image.image = ParagraphImage(fileName: "pic.jpg", width: 10, height: 10)
    let result = ParagraphMutation.insertDivider([a, image], after: a.id)

    XCTAssertEqual(kinds(result.paragraphs), [.body, .divider, .body, .image])
    XCTAssertEqual(result.focusID, result.paragraphs[2].id)
  }

  func testInsertImagePadsWithEmptyBodies() {
    let p = body("x")
    let image = ParagraphImage(fileName: "pic.jpg", width: 100, height: 50, caption: "cap")
    let result = ParagraphMutation.insertImage([p], after: p.id, image: image)

    XCTAssertEqual(kinds(result.paragraphs), [.body, .body, .image, .body])
    XCTAssertEqual(result.paragraphs[2].image, image)
    XCTAssertEqual(result.focusID, result.paragraphs[3].id)
  }

  // MARK: - Deletion

  func testDeleteImageFocusesNextTextParagraph() {
    let a = body("A")
    let image = Paragraph(kind: .image)
    let b = body("B")
    let result = ParagraphMutation.delete([a, image, b], id: image.id)

    XCTAssertEqual(result.paragraphs.count, 2)
    XCTAssertEqual(texts(result.paragraphs), ["A", "B"])
    XCTAssertEqual(result.focusID, b.id)
  }

  func testDeleteLastParagraphFocusesPrevious() {
    let a = body("A")
    let image = Paragraph(kind: .image)
    let result = ParagraphMutation.delete([a, image], id: image.id)

    XCTAssertEqual(result.paragraphs.count, 1)
    XCTAssertEqual(result.focusID, a.id)
  }

  // MARK: - List flag normalization

  func testNormalizeMarksLastOfEachListRun() {
    let l1 = list("1")
    let l2 = list("2")
    var l3 = list("3")
    l3.isLastInList = false

    let result = ParagraphMutation.normalize([l1, l2, body("x"), l3])

    XCTAssertFalse(result[0].isLastInList)
    XCTAssertTrue(result[1].isLastInList)
    XCTAssertFalse(result[2].isLastInList)  // body never carries the flag
    XCTAssertTrue(result[3].isLastInList)  // single-item trailing run
  }

  func testNormalizeSingleListItem() {
    let l = list("x")
    let result = ParagraphMutation.normalize([l])
    XCTAssertTrue(result[0].isLastInList)
  }
}
