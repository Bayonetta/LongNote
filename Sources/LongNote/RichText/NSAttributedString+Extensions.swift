#if canImport(UIKit)
  import Foundation
  import LongNoteCore

  extension NSAttributedString {
    /// The plain text of the attributed string.
    public var plainText: String {
      string
    }

    /// HTML → attributed string, used for future import features. Not wired into
    /// the editor (the editor stores lossless keyed archives instead).
    public static func fromHTML(_ html: String) -> NSAttributedString? {
      guard let data = html.data(using: .utf8) else { return nil }
      let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
        .documentType: NSAttributedString.DocumentType.html,
        .characterEncoding: String.Encoding.utf8.rawValue,
      ]
      return try? NSAttributedString(data: data, options: options, documentAttributes: nil)
    }

    /// Attributed string → HTML data, for export/import interop.
    public var htmlData: Data? {
      let range = NSRange(location: 0, length: length)
      return try? data(
        from: range, documentAttributes: [.documentType: NSAttributedString.DocumentType.html])
    }
  }

  extension CodableAttributedString {
    /// SwiftUI `AttributedString` used by the non-interactive renderer. The bridge
    /// converts UIKit fonts/colors into SwiftUI attribute values.
    public var swiftUI: AttributedString {
      AttributedString(uiText)
    }
  }
#endif
