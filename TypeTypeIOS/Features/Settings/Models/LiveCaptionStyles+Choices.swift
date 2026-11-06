import Foundation

// The caption choices of the Android TV app, kept in the same server fields: a size in percent, a text colour and
// the opacity of the black box behind the text.
extension LiveCaptionStyles {
  static let sizes = [75, 100, 125, 150, 200]
  static let colors = ["#ffffff", "#ffeb3b", "#00e5ff", "#69f0ae"]
  static let backgrounds = [0, 50, 100]

  var sizePercent: Int { Self.percent(fontSize) ?? 100 }
  var backgroundOpacityPercent: Int { Self.percent(textBackgroundOpacity) ?? 100 }
  var foregroundColor: String { textColor.isEmpty ? "#ffffff" : textColor }

  func nextSize() -> LiveCaptionStyles {
    var next = self
    next.fontSize = "\(Self.sizes[(Self.nearest(sizePercent, in: Self.sizes) + 1) % Self.sizes.count])%"
    return next
  }

  func nextColor() -> LiveCaptionStyles {
    let index = Self.colors.firstIndex { $0.caseInsensitiveCompare(foregroundColor) == .orderedSame } ?? 0
    var next = self
    next.textColor = Self.colors[(index + 1) % Self.colors.count]
    return next
  }

  func nextBackground() -> LiveCaptionStyles {
    var next = self
    if next.textBackground.isEmpty { next.textBackground = "#000000" }
    next.textBackgroundOpacity = "\(Self.backgrounds[(Self.nearest(backgroundOpacityPercent, in: Self.backgrounds) + 1) % Self.backgrounds.count])%"
    return next
  }

  private static func percent(_ value: String) -> Int? {
    Int(value.hasSuffix("%") ? String(value.dropLast()) : value)
  }

  private static func nearest(_ value: Int, in list: [Int]) -> Int {
    list.indices.min { abs(list[$0] - value) < abs(list[$1] - value) } ?? 0
  }
}
