#if canImport(UIKit)
  import UIKit
  import LongNoteCore

  extension CodableAttributedString {
    /// The paragraph's text with the block's typography applied and the runs'
    /// own styling layered on top.
    ///
    /// This is the single place where "block owns typography, run owns
    /// deviations" is resolved, so the editor and the exported image always
    /// agree — and a paragraph that carries no explicit font still renders at
    /// its kind's size (H1 = 22 pt, quote = 15 pt, …).
    public func styledText(_ kind: ParagraphKind) -> NSAttributedString {
      let base = kind.baseAttributes
      let result = NSMutableAttributedString()
      for run in runs {
        var attributes = base
        if run.bold == true || run.italic == true {
          attributes[.font] = kind.baseFont.withTraits(
            bold: run.bold == true, italic: run.italic == true)
        }
        if let color = run.color {
          attributes[.foregroundColor] = color.uiColor
        }
        if run.strike == true {
          attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }
        if let link = run.link {
          attributes[.link] = link
        }
        result.append(NSAttributedString(string: run.text, attributes: attributes))
      }
      return result
    }
  }

  extension UIFont {
    /// The same font with the bold/italic traits forced on or off.
    func withTraits(bold: Bool, italic: Bool) -> UIFont {
      var traits = fontDescriptor.symbolicTraits
      if bold { traits.insert(.traitBold) } else { traits.remove(.traitBold) }
      if italic { traits.insert(.traitItalic) } else { traits.remove(.traitItalic) }
      guard let descriptor = fontDescriptor.withSymbolicTraits(traits) else { return self }
      return UIFont(descriptor: descriptor, size: pointSize)
    }
  }
#endif
