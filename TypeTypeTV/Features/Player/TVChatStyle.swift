import SwiftUI

enum TVChatLayout: String, CaseIterable {
  case over
  case beside

  static let key = "tv.chat.layout"

  var title: String {
    switch self {
    case .over: String(localized: "Over the picture")
    case .beside: String(localized: "Beside the picture")
    }
  }

  var width: CGFloat {
    switch self {
    case .over: 600
    case .beside: 480
    }
  }
}

enum TVChatDensity: String, CaseIterable {
  case small
  case medium
  case large

  static let key = "tv.chat.text"

  var title: String {
    switch self {
    case .small: String(localized: "Small")
    case .medium: String(localized: "Medium")
    case .large: String(localized: "Large")
    }
  }

  var font: Font {
    switch self {
    case .small: .system(size: 23)
    case .medium: .system(size: 27)
    case .large: .system(size: 32)
    }
  }

  var emote: CGFloat {
    switch self {
    case .small: 32
    case .medium: 38
    case .large: 46
    }
  }

  var badge: CGFloat {
    switch self {
    case .small: 22
    case .medium: 26
    case .large: 30
    }
  }

  var spacing: CGFloat {
    switch self {
    case .small: 6
    case .medium: 9
    case .large: 12
    }
  }
}

struct TVChatSurface<Content: View>: View {
  let layout: TVChatLayout
  let dimmed: Bool
  @ViewBuilder let content: Content

  var body: some View {
    content
      .padding(.leading, layout == .over ? 72 : 28)
      .padding(.trailing, TVDimens.safeEnd)
      .padding(.vertical, 64)
      .frame(width: layout.width, alignment: .leading)
      .frame(maxHeight: .infinity)
      .background { background.ignoresSafeArea() }
      .opacity(dimmed ? 0.08 : 1)
      .animation(.easeOut(duration: 0.25), value: dimmed)
      .accessibilityHidden(true)
  }

  @ViewBuilder
  private var background: some View {
    switch layout {
    case .over:
      LinearGradient(
        stops: [
          .init(color: TVPalette.ink.opacity(0), location: 0),
          .init(color: TVPalette.ink.opacity(0.74), location: 0.2),
          .init(color: TVPalette.ink.opacity(0.84), location: 1),
        ],
        startPoint: .leading,
        endPoint: .trailing
      )
    case .beside:
      TVPalette.surface
    }
  }
}
