import SwiftUI

enum TVPalette {
  static let ink = Color(hex24: 0x09090B)
  static let surface = Color(hex24: 0x18181B)
  static let surfaceRaised = Color(hex24: 0x27272A)
  static let outline = Color(hex24: 0x3F3F46)
  static let textHigh = Color(hex24: 0xF4F4F5)
  static let textMid = Color(hex24: 0xA1A1AA)
  static let textLow = Color(hex24: 0x71717A)
  static let accent = Color(hex24: 0xEF4444)
  static let accentSoft = Color(hex24: 0xFCA5A5)
  static let glass = Color(hex24: 0xF4F4F5).opacity(0.2)
  static let glassStrong = Color(hex24: 0xF4F4F5).opacity(0.3)
  static let success = Color(hex24: 0x34D399)
}

extension Color {
  init(hex24: UInt32) {
    self.init(
      red: Double((hex24 >> 16) & 0xFF) / 255,
      green: Double((hex24 >> 8) & 0xFF) / 255,
      blue: Double(hex24 & 0xFF) / 255
    )
  }
}

enum TVType {
  static let display = Font.system(size: 76, weight: .semibold)
  static let headline = Font.system(size: 48, weight: .semibold)
  static let title = Font.system(size: 30, weight: .semibold)
  static let body = Font.system(size: 28)
  static let meta = Font.system(size: 24, weight: .medium)
  static let label = Font.system(size: 22, weight: .semibold)
  static let button = Font.system(size: 28, weight: .semibold)
}

enum TVDimens {
  static let safeStart: CGFloat = 112
  static let safeEnd: CGFloat = 80
  static let panelRadius: CGFloat = 28
  static let cardRadius: CGFloat = 20
  static let focusScale: CGFloat = 1.06
  static let focusScaleSmall: CGFloat = 1.035
}
