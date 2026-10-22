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
      // Line spacing belongs to the block too, so every paragraph of a kind
      // breathes the same way (original kLineHeight*).
      let paragraphStyle = NSMutableParagraphStyle()
      paragraphStyle.lineSpacing = kind.lineSpacing
      paragraphStyle.alignment = Self.alignment(for: string)
      var base = kind.baseAttributes
      base[.paragraphStyle] = paragraphStyle
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

  extension CodableAttributedString {
    /// The original justifies every paragraph. That reads well for CJK text but
    /// produces rivers in a narrow column of Latin text, so justification is
    /// kept for CJK-heavy content and Latin falls back to natural alignment.
    static func alignment(for text: String) -> NSTextAlignment {
      guard !text.isEmpty else { return .natural }
      var cjk = 0
      for scalar in text.unicodeScalars {
        switch scalar.value {
        case 0x3040...0x30FF, 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF:
          cjk += 1
        default:
          break
        }
      }
      return cjk * 3 >= text.unicodeScalars.count ? .justified : .natural
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
