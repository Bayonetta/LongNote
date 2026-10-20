#if canImport(UIKit)
  import UIKit
  import LongNoteCore

  /// A rich-text edit the toolbar asks a focused paragraph to apply. The action is
  /// delivered to the paragraph's live `UITextView` (through `RichTextView`) so it
  /// can operate on the current selection *and* the typing attributes.
  public enum RichTextAction: Equatable {
    /// Toggle bold on the selection, or on newly typed text when there is none.
    case toggleBold
    /// Toggle strikethrough on the selection / typing attributes.
    case toggleStrikethrough
    /// Apply a foreground color to the selection / typing attributes.
    case setColor(TextStyle.RGBColor)
    /// Attach (or remove, when nil) a link on the selection / typing attributes.
    case setLink(URL?)
    /// Reset the whole paragraph to a kind's base font/color and its typing
    /// attributes (used by the paragraph-style menu).
    case setParagraphStyle(ParagraphKind)
  }

  extension UITextView {
    /// Applies a `RichTextAction` in place. Direct `textStorage` mutations below
    /// fire `textViewDidChange`, which keeps the document model in sync.
    func applyRichTextAction(_ action: RichTextAction) {
      switch action {
      case .toggleBold:
        let currentFont = font(inSelectionOrTyping: selectedRange)
        let newFont = currentFont.togglingBold()
        if selectedRange.length > 0 {
          textStorage.addAttribute(.font, value: newFont, range: selectedRange)
        }
        typingAttributes[.font] = newFont

      case .toggleStrikethrough:
        let current = strikethroughState(inSelectionOrTyping: selectedRange)
        let newValue: Int = (current == 0) ? NSUnderlineStyle.single.rawValue : 0
        if selectedRange.length > 0 {
          textStorage.addAttribute(
            .strikethroughStyle, value: NSNumber(value: newValue), range: selectedRange)
        }
        typingAttributes[.strikethroughStyle] = (newValue == 0) ? nil : NSNumber(value: newValue)

      case .setColor(let color):
        let uiColor = color.uiColor
        if selectedRange.length > 0 {
          textStorage.addAttribute(.foregroundColor, value: uiColor, range: selectedRange)
        }
        typingAttributes[.foregroundColor] = uiColor

      case .setLink(let url):
        if selectedRange.length > 0 {
          if let url {
            textStorage.addAttribute(.link, value: url, range: selectedRange)
          } else {
            textStorage.removeAttribute(.link, range: selectedRange)
          }
        }
        typingAttributes[.link] = url

      case .setParagraphStyle(let kind):
        let whole = NSRange(location: 0, length: textStorage.length)
        if whole.length > 0 {
          textStorage.beginEditing()
          textStorage.addAttribute(.font, value: kind.baseFont, range: whole)
          textStorage.addAttribute(.foregroundColor, value: kind.baseColor, range: whole)
          textStorage.endEditing()
        }
        typingAttributes = [.font: kind.baseFont, .foregroundColor: kind.baseColor]
      }
    }

    /// The font at the selection's start, or from the typing attributes when the
    /// selection is empty (safe against an out-of-bounds empty text storage).
    private func font(inSelectionOrTyping range: NSRange) -> UIFont {
      let fallback = UIFont.systemFont(ofSize: TextStyle.bodyFontSize)
      if range.length > 0, range.location < textStorage.length {
        return textStorage.attribute(.font, at: range.location, effectiveRange: nil) as? UIFont
          ?? fallback
      }
      return typingAttributes[.font] as? UIFont ?? fallback
    }

    private func strikethroughState(inSelectionOrTyping range: NSRange) -> Int {
      if range.length > 0, range.location < textStorage.length {
        return
          (textStorage.attribute(.strikethroughStyle, at: range.location, effectiveRange: nil)
          as? Int) ?? 0
      }
      return (typingAttributes[.strikethroughStyle] as? Int) ?? 0
    }
  }

  extension UIFont {
    /// Returns a font with the bold symbolic trait toggled (bold → regular, and
    /// regular → bold), preserving the family and size.
    fileprivate func togglingBold() -> UIFont {
      let traits = fontDescriptor.symbolicTraits
      let toggled: UIFontDescriptor.SymbolicTraits =
        traits.contains(.traitBold) ? traits.subtracting(.traitBold) : traits.union(.traitBold)
      guard let descriptor = fontDescriptor.withSymbolicTraits(toggled) else { return self }
      return UIFont(descriptor: descriptor, size: pointSize)
    }
  }
#endif
