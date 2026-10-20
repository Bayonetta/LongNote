import Foundation
import LongNote
import UIKit

/// A ready-made sample article for the demo app's "Load Sample Article" action.
///
/// Keeping sample content in the *demo target* (instead of the library) means
/// an interviewer — or screenshot tooling — sees a fully populated editor on
/// first open, while the library itself stays free of fixture data.
enum SampleArticle {

  static func make() -> Article {
    Article(
      title: "LongNote — a long-image editor component library",
      summary: "A SwiftUI + TextKit 2 rebuild of a classic long-article editor: per-paragraph rich text, mixed block layout, long-image export and autosaved drafts.",
      paragraphs: [
        para(.title, "Welcome to LongNote"),
        para(
          .body,
          "This is a sample article. Every paragraph is its own UITextView (TextKit 2), so any selection can carry its own bold, strikethrough, color or link — exactly like a classic long-article editor."
        ),
        Paragraph(kind: .body, text: richBody()),
        para(.header, "Things to try"),
        para(.list, "Press Return to split a paragraph; Backspace at a line start merges it back"),
        para(.list, "Select text and use the floating toolbar for bold / strikethrough / color / link"),
        para(.list, "Use the bottom toolbar to switch block styles, or insert a divider or image", isLastInList: true),
        para(.quote, "\"Good tools get out of the way.\" — tap the share icon to export a long image"),
        Paragraph(kind: .divider),
        para(
          .body,
          "Kill and relaunch the app — your draft is still here: it autosaves 2 s after you stop typing. Exported long images can be saved to Photos or shared anywhere."
        ),
      ]
    )
  }

  // MARK: - Helpers

  private static func para(
    _ kind: ParagraphKind, _ text: String, isLastInList: Bool = false
  ) -> Paragraph {
    Paragraph(kind: kind, text: .init(string: text), isLastInList: isLastInList)
  }

  /// One body paragraph containing a bold run, to show per-range styling.
  private static func richBody() -> CodableAttributedString {
    let text = NSMutableAttributedString(string: "A run inside this paragraph is ")
    text.append(
      NSAttributedString(
        string: "bold",
        attributes: [.font: UIFont.boldSystemFont(ofSize: 15)]
      ))
    text.append(NSAttributedString(string: ", so any selection can carry its own style."))
    return CodableAttributedString(text)
  }
}
