import Foundation

/// Pure, testable paragraph editing operations — the heart of the editor.
///
/// Every operation takes the current `[Paragraph]` plus an intent and returns a
/// `Result` describing the new paragraph list and where the editor should move
/// focus/cursor next. Nothing here touches UIKit (or even SwiftUI), so the whole
/// file can be unit-tested on any platform, including Windows/Linux.
///
/// This mirrors the `shouldChangeTextInRange:` logic of the original Objective-C
/// editor: Return splits, backspace-at-start merges, `- <space>` converts to a
/// list, pasting multi-line text splits into paragraphs, and inserting a divider
/// or image pads the flow with empty body paragraphs so text never abuts a block.
public enum ParagraphMutation {

  // MARK: - Result

  /// The outcome of a mutation: the new list plus what the editor should do next.
  public struct Result: Equatable {
    public var paragraphs: [Paragraph]
    /// Paragraph to focus next. `nil` means "leave focus where it is".
    public var focusID: Paragraph.ID?
    /// Cursor placement inside `focusID` (nil = leave the current selection).
    public var selection: NSRange?

    public init(paragraphs: [Paragraph], focusID: Paragraph.ID?, selection: NSRange? = nil) {
      self.paragraphs = paragraphs
      self.focusID = focusID
      self.selection = selection
    }
  }

  // MARK: - Return key

  /// Full Return-key behaviour for a focused paragraph:
  /// - an *empty* list item cancels the list (converts to body);
  /// - anything else splits the paragraph at the cursor.
  public static func returnKey(_ paragraphs: [Paragraph], id: Paragraph.ID, location: Int) -> Result
  {
    guard let paragraph = paragraphs.first(where: { $0.id == id }) else {
      return Result(paragraphs: paragraphs, focusID: nil, selection: nil)
    }
    if paragraph.kind == .list, paragraph.text.isEmpty {
      return convert(paragraphs, id: id, to: .body)
    }
    return split(paragraphs, id: id, at: location)
  }

  // MARK: - Split

  /// Pressing Return: split `id` at `location` (a character offset in its text).
  ///
  /// The head stays in the current paragraph; the tail becomes a new paragraph
  /// inserted right after it and gets the focus. A list item keeps flowing as a
  /// list; every other kind continues as `.body`.
  public static func split(_ paragraphs: [Paragraph], id: Paragraph.ID, at location: Int) -> Result
  {
    guard let index = paragraphs.firstIndex(where: { $0.id == id }) else {
      return Result(paragraphs: paragraphs, focusID: nil, selection: nil)
    }
    var out = paragraphs
    let current = out[index]
    let text = current.text.uiText
    let location = min(max(location, 0), text.length)

    let tailKind: ParagraphKind = (current.kind == .list) ? .list : .body

    let head = text.attributedSubstring(from: NSRange(location: 0, length: location))
    let tail = text.attributedSubstring(
      from: NSRange(location: location, length: text.length - location))

    var newHead = current
    newHead.text = CodableAttributedString(head)
    newHead.isLastInList = false

    var newTail = Paragraph(kind: tailKind, text: CodableAttributedString(tail))
    newTail.isLastInList = current.isLastInList

    out[index] = newHead
    out.insert(newTail, at: index + 1)

    return Result(
      paragraphs: normalize(out),
      focusID: newTail.id,
      selection: NSRange(location: 0, length: 0)
    )
  }

  // MARK: - Merge

  /// Backspace at the very start of `id`: merge it into the previous paragraph.
  ///
  /// Divider (and image) blocks sitting directly before the paragraph are
  /// removed rather than merged into, so text never gets pasted onto a block.
  /// The cursor lands at the junction between the two texts.
  public static func mergeIntoPrevious(_ paragraphs: [Paragraph], id: Paragraph.ID) -> Result {
    guard let index = paragraphs.firstIndex(where: { $0.id == id }) else {
      return Result(paragraphs: paragraphs, focusID: nil, selection: nil)
    }
    if index == 0 {
      // First paragraph: nothing to merge with.
      return Result(paragraphs: paragraphs, focusID: id, selection: NSRange(location: 0, length: 0))
    }

    var out = paragraphs
    let current = out.remove(at: index)

    // Skip divider/image blocks directly above and drop them.
    var targetIndex = index - 1
    while targetIndex >= 0, !out[targetIndex].kind.isTextKind {
      out.remove(at: targetIndex)
      targetIndex -= 1
    }

    guard targetIndex >= 0 else {
      // Only blocks were above — the current paragraph becomes the first one.
      out.insert(current, at: 0)
      return Result(
        paragraphs: normalize(out), focusID: id, selection: NSRange(location: 0, length: 0))
    }

    let target = out[targetIndex]
    let mergePoint = target.text.uiText.length

    let merged = NSMutableAttributedString(attributedString: target.text.uiText)
    merged.append(current.text.uiText)
    var updated = target
    updated.text = CodableAttributedString(merged)

    out[targetIndex] = updated
    return Result(
      paragraphs: normalize(out),
      focusID: target.id,
      selection: NSRange(location: mergePoint, length: 0)
    )
  }

  // MARK: - Convert kind

  /// Change a paragraph's kind (body → quote, body → list, list → body, ...).
  public static func convert(_ paragraphs: [Paragraph], id: Paragraph.ID, to kind: ParagraphKind)
    -> Result
  {
    guard let index = paragraphs.firstIndex(where: { $0.id == id }) else {
      return Result(paragraphs: paragraphs, focusID: nil, selection: nil)
    }
    guard kind.isTextKind else {
      // Blocks are inserted, not converted into.
      return Result(paragraphs: paragraphs, focusID: id, selection: nil)
    }
    var out = paragraphs
    var paragraph = out[index]
    paragraph.kind = kind
    paragraph.isLastInList = (kind == .list)
    out[index] = paragraph
    return Result(paragraphs: normalize(out), focusID: id, selection: nil)
  }

  // MARK: - Paste

  /// Replace `range` in `id` with the first line of `pasted`, then insert each
  /// remaining non-empty line as a new `.body` paragraph after it.
  ///
  /// Focus lands on the last inserted line with the cursor at its end, so a
  /// multi-line paste reads top to bottom.
  public static func splitPastedText(
    _ paragraphs: [Paragraph],
    id: Paragraph.ID,
    range: NSRange,
    pasted: String
  ) -> Result {
    guard let index = paragraphs.firstIndex(where: { $0.id == id }) else {
      return Result(paragraphs: paragraphs, focusID: nil, selection: nil)
    }

    var lines = pasted.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    // A paste ending in "\n" would otherwise manufacture a trailing empty
    // paragraph — drop the empty tail instead.
    while let last = lines.last, last.isEmpty {
      lines.removeLast()
    }
    guard !lines.isEmpty else {
      return Result(paragraphs: paragraphs, focusID: id, selection: nil)
    }

    var out = paragraphs
    var current = out[index]
    let firstLine = lines[0]

    let replaced = NSMutableAttributedString(attributedString: current.text.uiText)
    replaced.replaceCharacters(in: range, with: firstLine)
    current.text = CodableAttributedString(replaced)
    out[index] = current

    let tailLines = lines.dropFirst()
    let newParagraphs = tailLines.map {
      Paragraph(kind: .body, text: CodableAttributedString(string: $0))
    }
    out.insert(contentsOf: newParagraphs, at: index + 1)

    let lastParagraphID = newParagraphs.last?.id ?? current.id
    let lastLength = (newParagraphs.last?.text.uiText.length ?? firstLine.utf16.count)
    return Result(
      paragraphs: normalize(out),
      focusID: lastParagraphID,
      selection: NSRange(location: lastLength, length: 0)
    )
  }

  // MARK: - Block insertion

  /// Insert a divider after `id`, padded by an empty body paragraph on each side
  /// so the divider never touches text directly and backspace-merge stays sane.
  public static func insertDivider(_ paragraphs: [Paragraph], after id: Paragraph.ID) -> Result {
    guard let index = paragraphs.firstIndex(where: { $0.id == id }) else {
      return Result(paragraphs: paragraphs, focusID: nil, selection: nil)
    }
    var out = paragraphs
    let leading = Paragraph.empty(.body)
    let divider = Paragraph(kind: .divider)
    let trailing = Paragraph.empty(.body)
    out.insert(contentsOf: [leading, divider, trailing], at: index + 1)
    return Result(
      paragraphs: normalize(out),
      focusID: trailing.id,
      selection: NSRange(location: 0, length: 0)
    )
  }

  /// Insert an image paragraph after `id`, padded by an empty body on each side.
  public static func insertImage(
    _ paragraphs: [Paragraph],
    after id: Paragraph.ID,
    image: ParagraphImage
  ) -> Result {
    guard let index = paragraphs.firstIndex(where: { $0.id == id }) else {
      return Result(paragraphs: paragraphs, focusID: nil, selection: nil)
    }
    var out = paragraphs
    let leading = Paragraph.empty(.body)
    var imageParagraph = Paragraph(kind: .image)
    imageParagraph.image = image
    let trailing = Paragraph.empty(.body)
    out.insert(contentsOf: [leading, imageParagraph, trailing], at: index + 1)
    return Result(
      paragraphs: normalize(out),
      focusID: trailing.id,
      selection: NSRange(location: 0, length: 0)
    )
  }

  // MARK: - Deletion

  /// Remove a paragraph (image/divider block, or a text paragraph) and move the
  /// focus to the nearest editable paragraph.
  public static func delete(_ paragraphs: [Paragraph], id: Paragraph.ID) -> Result {
    guard let index = paragraphs.firstIndex(where: { $0.id == id }) else {
      return Result(paragraphs: paragraphs, focusID: nil, selection: nil)
    }
    var out = paragraphs
    out.remove(at: index)
    let focusID = focusCandidate(in: out, near: index)
    return Result(
      paragraphs: normalize(out),
      focusID: focusID,
      selection: focusID != nil ? NSRange(location: 0, length: 0) : nil
    )
  }

  // MARK: - List flag normalization

  /// Recompute `isLastInList` so that within each consecutive run of `.list`
  /// paragraphs exactly the last item carries the extra bottom spacing.
  /// Call after any operation that can reorder or reclassify paragraphs.
  public static func normalize(_ paragraphs: [Paragraph]) -> [Paragraph] {
    var out = paragraphs
    var index = 0
    while index < out.count {
      if out[index].kind == .list {
        var runEnd = index
        while runEnd + 1 < out.count, out[runEnd + 1].kind == .list {
          runEnd += 1
        }
        for i in index..<runEnd {
          out[i].isLastInList = false
        }
        out[runEnd].isLastInList = true
        index = runEnd + 1
      } else {
        out[index].isLastInList = false
        index += 1
      }
    }
    return out
  }

  // MARK: - Helpers

  /// Nearest editable paragraph to `index`, preferring the one that shifted into
  /// the deleted slot, then its forward neighbor, then backward, then any.
  private static func focusCandidate(in paragraphs: [Paragraph], near index: Int) -> Paragraph.ID? {
    for i in index..<paragraphs.count where paragraphs[i].kind.isTextKind {
      return paragraphs[i].id
    }
    for i in stride(from: index - 1, through: 0, by: -1) where paragraphs[i].kind.isTextKind {
      return paragraphs[i].id
    }
    return paragraphs.first?.id
  }
}
