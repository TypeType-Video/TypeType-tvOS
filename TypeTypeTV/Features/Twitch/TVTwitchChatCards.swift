import SwiftUI

struct TVTwitchPinnedCard: View {
  let pinned: LiveTwitchPinnedMessage
  @State private var collapsed = false

  var body: some View {
    TVTwitchChatCard {
      if collapsed {
        Label {
          Text(verbatim: "\(pinned.author): \(pinned.text)").lineLimit(1)
        } icon: {
          Image(systemName: "pin.fill").foregroundStyle(TVPalette.accentSoft)
        }
        .font(TVType.label)
      } else {
        if let by = pinned.pinnedBy {
          Label { Text("Pinned by \(by)") } icon: { Image(systemName: "pin.fill") }
            .font(TVType.label)
            .foregroundStyle(TVPalette.textMid)
        }
        Text(verbatim: "\(pinned.author): \(pinned.text)").font(TVType.meta).lineLimit(3)
      }
    }
    .animation(.easeOut(duration: 0.3), value: collapsed)
    .task(id: pinned.id) {
      collapsed = false
      guard (try? await Task.sleep(for: .seconds(12))) != nil else { return }
      collapsed = true
    }
  }
}

struct TVTwitchPollCard: View {
  let poll: LiveTwitchPoll

  var body: some View {
    TVTwitchChatCard {
      Label { Text(verbatim: poll.title).lineLimit(2) } icon: { Image(systemName: "chart.bar.fill") }
        .font(TVType.meta.weight(.semibold))
      ForEach(poll.choices.prefix(4)) { choice in
        let percent = LiveTwitchChatText.percent(choice, in: poll)
        VStack(alignment: .leading, spacing: 4) {
          HStack {
            Text(verbatim: choice.title).lineLimit(1)
            Spacer()
            Text(verbatim: "\(percent)%").monospacedDigit()
          }
          .font(TVType.label)
          GeometryReader { proxy in
            Capsule().fill(TVPalette.glass)
              .overlay(alignment: .leading) {
                Capsule().fill(TVPalette.accent).frame(width: proxy.size.width * CGFloat(percent) / 100)
              }
          }
          .frame(height: 6)
        }
      }
    }
  }
}

struct TVTwitchChatCard<Content: View>: View {
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 8) { content }
      .foregroundStyle(TVPalette.textHigh)
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
  }
}
