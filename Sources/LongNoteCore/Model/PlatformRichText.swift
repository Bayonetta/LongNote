import Foundation

#if canImport(UIKit)
  import UIKit
#elseif canImport(AppKit)
  import AppKit
#endif

/// Bridges between `NSAttributedString` and the semantic `TextRun` model.
///
/// Apple platforms can read font traits and colours, so documents round-trip
/// losslessly there. Foundation-only platforms (Linux, Windows) fall back to
/// plain text: the *file* stays fully readable — runs, flags and colours are
/// plain JSON — only the in-memory attributed string loses styling there.
enum PlatformRichText {

  /// The semantic styling carried by one attribute run.
  static func style(from attributes: [NSAttributedString.Key: Any])
    -> (bold: Bool?, italic: Bool?, strike: Bool?, color: TextStyle.RGBColor?, link: URL?)
  {
    let strike: Bool? =
      (attributes[.strikethroughStyle] as? Int).flatMap { $0 == 0 ? nil : true }
    let link = attributes[.link] as? URL

    #if canImport(UIKit)
      let traits = (attributes[.font] as? UIFont)?.fontDescriptor.symbolicTraits
      let bold: Bool? = (traits?.contains(.traitBold) == true) ? true : nil
      let italic: Bool? = (traits?.contains(.traitItalic) == true) ? true : nil
      let color = (attributes[.foregroundColor] as? UIColor)
        .flatMap(TextStyle.RGBColor.init(uiColor:))
        .flatMap { $0 == TextStyle.textColor ? nil : $0 }
      return (bold, italic, strike, color, link)
    #elseif canImport(AppKit)
      let traits = (attributes[.font] as? NSFont)?.fontDescriptor.symbolicTraits
      let bold: Bool? = (traits?.contains(.bold) == true) ? true : nil
      let italic: Bool? = (traits?.contains(.italic) == true) ? true : nil
      let color = (attributes[.foregroundColor] as? NSColor)
        .flatMap(TextStyle.RGBColor.init(nsColor:))
        .flatMap { $0 == TextStyle.textColor ? nil : $0 }
      return (bold, italic, strike, color, link)
    #else
      return (nil, nil, strike, nil, link)
    #endif
  }

  /// Appends `run` to `result` with only the run's own styling applied.
  ///
  /// No block typography is added here on purpose — the view applies it through
  /// `styledText(_:)`, so decoding never has to guess the paragraph kind.
  static func append(_ run: TextRun, to result: NSMutableAttributedString) {
    var attributes: [NSAttributedString.Key: Any] = [:]
    #if canImport(UIKit)
      if run.bold == true || run.italic == true {
        var font = UIFont.systemFont(ofSize: TextStyle.bodyFontSize)
        var traits = font.fontDescriptor.symbolicTraits
        if run.bold == true { traits.insert(.traitBold) }
        if run.italic == true { traits.insert(.traitItalic) }
        if let descriptor = font.fontDescriptor.withSymbolicTraits(traits) {
          font = UIFont(descriptor: descriptor, size: font.pointSize)
        }
        attributes[.font] = font
      }
      if let color = run.color { attributes[.foregroundColor] = color.uiColor }
    #elseif canImport(AppKit)
      if run.bold == true || run.italic == true {
        var font = NSFont.systemFont(ofSize: TextStyle.bodyFontSize)
        var traits = font.fontDescriptor.symbolicTraits
        if run.bold == true { traits.insert(.bold) }
        if run.italic == true { traits.insert(.italic) }
        let descriptor = font.fontDescriptor.withSymbolicTraits(traits)
        font = NSFont(descriptor: descriptor, size: font.pointSize) ?? font
        attributes[.font] = font
      }
      if let color = run.color { attributes[.foregroundColor] = color.nsColor }
    #endif
    if run.strike == true {
      attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
    }
    if let link = run.link { attributes[.link] = link }
    result.append(NSAttributedString(string: run.text, attributes: attributes))
  }
}
