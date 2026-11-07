import SwiftUI

struct TVChannelStrip: View {
  let channels: [LiveSubscription]
  @Binding var selected: LiveSubscription?
  @FocusState private var focused: String?

  private static let allID = "all"

  var body: some View {
    ScrollView(.horizontal) {
      LazyHStack(spacing: 32) {
        chip(id: Self.allID, name: String(localized: "All"), description: String(localized: "All channels, shows every new video"),
             avatar: nil, isSelected: selected == nil) { selected = nil }
        ForEach(channels) { channel in
          chip(id: channel.channelURL, name: channel.name, description: String(localized: "\(channel.name), shows only its videos"),
               avatar: URL(string: channel.avatarURL), isSelected: selected?.channelURL == channel.channelURL) {
            selected = channel
          }
        }
      }
      .padding(.horizontal, TVDimens.safeStart)
      .padding(.vertical, 20)
    }
    .scrollClipDisabled()
    .focusSection()
    // Coming into the strip lands on the chip that is selected, as on Android TV.
    .defaultFocus($focused, selected?.channelURL ?? Self.allID, priority: .userInitiated)
  }

  private func chip(id: String, name: String, description: String, avatar: URL?, isSelected: Bool, action: @escaping () -> Void) -> some View {
    VStack(spacing: 16) {
      Button(action: action) {
        ZStack {
          TVPalette.surfaceRaised
          if let avatar {
            TVRemoteImage(url: avatar)
          } else if name == String(localized: "All") {
            Image(systemName: "rectangle.stack.fill").font(.system(size: 52)).foregroundStyle(TVPalette.textHigh)
          } else {
            Text(verbatim: String(name.prefix(1)).uppercased()).font(.system(size: 60, weight: .semibold))
              .foregroundStyle(TVPalette.textHigh)
          }
        }
        .frame(width: 152, height: 152)
        .clipShape(Circle())
        .overlay(Circle().stroke(isSelected ? TVPalette.accent : .clear, lineWidth: 6))
      }
      .buttonStyle(.borderless)
      .focused($focused, equals: id)
      .accessibilityLabel(Text(verbatim: description))
      .accessibilityAddTraits(isSelected ? .isSelected : [])
      Text(verbatim: name)
        .font(TVType.meta)
        .foregroundStyle(isSelected ? TVPalette.textHigh : TVPalette.textMid)
        .lineLimit(1)
        .frame(width: 200)
        .accessibilityHidden(true)
    }
  }
}
