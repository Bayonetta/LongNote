#if canImport(UIKit)
  import UIKit
  import SwiftUI
  import LongNoteCore

  extension TextStyle.RGBColor {
    /// UIKit color used by the editor.
    public var uiColor: UIColor {
      UIColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: CGFloat(alpha))
    }

    /// SwiftUI color used by the renderer.
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
      TextStyle.textColor.uiColor
    }

    /// Default typing attributes for fresh text of this kind.
    public var baseAttributes: [NSAttributedString.Key: Any] {
      [.font: baseFont, .foregroundColor: baseColor]
    }
  }
#endif
