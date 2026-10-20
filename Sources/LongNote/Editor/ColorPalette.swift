#if canImport(UIKit)
  import SwiftUI
  import LongNoteCore

  /// The 45-color text palette (mirrors the original editor's `wholeColors`): a spread of hues plus a
  /// grayscale ramp, presented as a grid in the color popover.
  enum ColorPalette {
    static let colors: [TextStyle.RGBColor] = [
      // Grayscale ramp
      .init(hex: 0x000000),
      .init(hex: 0x424242),
      .init(hex: 0x757575),
      .init(hex: 0x9E9E9E),
      .init(hex: 0xBCBCBC),
      .init(hex: 0xE0E0E0),
      // Reds
      .init(hex: 0x8C1D18),
      .init(hex: 0xD0021B),
      .init(hex: 0xFF3B30),
      .init(hex: 0xFF6B6B),
      .init(hex: 0xFFB4B4),
      // Oranges
      .init(hex: 0xD24A00),
      .init(hex: 0xF07F00),
      .init(hex: 0xFF9500),
      .init(hex: 0xFFB84D),
      .init(hex: 0xFFDD99),
      // Yellows
      .init(hex: 0x9C8C00),
      .init(hex: 0xD9C000),
      .init(hex: 0xFFD60D),
      .init(hex: 0xFFE55C),
      .init(hex: 0xFFF0A8),
      // Greens
      .init(hex: 0x1E7D32),
      .init(hex: 0x4CAF50),
      .init(hex: 0x8BC34A),
      .init(hex: 0xC0E57A),
      .init(hex: 0xD8F0B0),
      // Teals / cyans
      .init(hex: 0x00796B),
      .init(hex: 0x26A69A),
      .init(hex: 0x4DD0E1),
      .init(hex: 0x80DEEA),
      .init(hex: 0xB2EBF2),
      // Blues
      .init(hex: 0x0D47A1),
      .init(hex: 0x1976D2),
      .init(hex: 0x448AFF),
      .init(hex: 0x7FB3FF),
      .init(hex: 0xB3D4FF),
      // Purples / magentas
      .init(hex: 0x4A148C),
      .init(hex: 0x7B1FA2),
      .init(hex: 0xAA47FF),
      .init(hex: 0xC58AFF),
      .init(hex: 0xE1BEE7),
      // Extra warm neutrals
      .init(hex: 0x7A5548),
      .init(hex: 0xA1887F),
      .init(hex: 0x33691E),
      .init(hex: 0x01579B),
    ]
  }

  /// A grid of color swatches; tapping one reports the color back.
  @MainActor
  struct ColorPaletteView: View {
    let onSelect: (TextStyle.RGBColor) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 9)

    var body: some View {
      LazyVGrid(columns: columns, spacing: 8) {
        ForEach(Array(ColorPalette.colors.enumerated()), id: \.offset) { _, color in
          Button {
            onSelect(color)
          } label: {
            Circle()
              .fill(color.color)
              .frame(width: 22, height: 22)
          }
          .buttonStyle(.plain)
        }
      }
      .padding(12)
    }
  }
#endif
