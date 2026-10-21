#if canImport(UIKit)
  import UIKit
  import SwiftUI
  import LongNoteCore

  extension TextStyle.RGBColor {
    /// SwiftUI color used by the renderer. (`uiColor` lives in the core, so the
    /// storage codec can use it too.)
    public var color: Color {
      Color(red: red, green: green, blue: blue).opacity(alpha)
    }
  }

  extension ParagraphKind {
    /// Base font for a paragraph of this kind (shared by the editor and renderer
    /// so a converted paragraph keeps the same look when exported).
    public var baseFont: UIFont {
      switch self {
      case .title:
        return .systemFont(ofSize: TextStyle.heading1FontSize, weight: .bold)
      case .header:
        return .systemFont(ofSize: TextStyle.heading2FontSize, weight: .semibold)
      case .quote:
        return .systemFont(ofSize: TextStyle.quoteFontSize)
      case .list:
        return .systemFont(ofSize: TextStyle.listFontSize)
      default:
        return .systemFont(ofSize: TextStyle.bodyFontSize)
      }
    }

    public var baseColor: UIColor {
      self == .quote ? TextStyle.quoteTextColor.uiColor : TextStyle.textColor.uiColor
    }

    /// Extra leading between lines of this block (original `kLineHeight*`).
    public var lineSpacing: CGFloat {
      self == .quote ? TextStyle.lineSpacingQuote : TextStyle.lineSpacingText
    }

    /// Vertical insets of the paragraph's text view.
    public var textInsets: UIEdgeInsets {
      UIEdgeInsets(top: 2, left: 0, bottom: 2, right: 0)
    }

    /// Horizontal space the row spends around its text: the leading/trailing
    /// padding plus the bullet or quote-bar column.
    public var textHorizontalInset: CGFloat {
      switch self {
      case .quote:
        return TextStyle.quoteInset + TextStyle.quoteRightInset + TextStyle.quoteBarWidth + 14
      case .list:
        return TextStyle.editorHorizontalInset * 2 + 22 + 10
      default:
        return TextStyle.editorHorizontalInset * 2
      }
    }

    /// Default typing attributes for fresh text of this kind.
    public var baseAttributes: [NSAttributedString.Key: Any] {
      [.font: baseFont, .foregroundColor: baseColor]
    }
  }
#endif
