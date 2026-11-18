import SwiftUI

struct TVTwitchChatColumn: View {
  @ObservedObject var controller: LivePlayerController
  let chat: TVTwitchChat
  let underControls: Bool

  var body: some View {
    Group {
      if let live = chat.live {
        TVTwitchLiveChatLines(model: live)
      } else if let replay = chat.replay {
        TVTwitchReplayLines(controller: controller, model: replay)
      }
    }
    .padding(.leading, 28)
    .padding(.trailing, TVDimens.safeEnd)
    .padding(.top, 92)
    .padding(.bottom, underControls ? 220 : 80)
    .frame(width: TVLiveChatPanel.width, alignment: .leading)
    .frame(maxHeight: .infinity)
    .background(TVPalette.surface.ignoresSafeArea())
    .accessibilityHidden(true)
  }
}

struct TVTwitchLiveChatLines: View {
  @ObservedObject var model: LiveTwitchChatViewModel

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      TVTwitchChatHeader(title: "LIVE CHAT", active: model.status == .live)
      if let pinned = model.visiblePinned {
        TVTwitchChatCard {
          if let by = pinned.pinnedBy { Text("Pinned by \(by)").font(TVType.label).foregroundStyle(TVPalette.textMid) }
          Text(verbatim: "\(pinned.author): \(pinned.text)").font(TVType.meta).lineLimit(3)
        }
      }
      if let poll = model.visiblePoll {
        TVTwitchChatCard {
          Text(verbatim: poll.title).font(TVType.meta.weight(.semibold)).lineLimit(2)
          ForEach(poll.choices) { choice in
            HStack {
              Text(verbatim: choice.title).lineLimit(1)
              Spacer()
              Text(verbatim: "\(LiveTwitchChatText.percent(choice, in: poll))%").monospacedDigit()
            }
            .font(TVType.label)
          }
        }
      }
      if let room = model.chat.room, !LiveTwitchChatText.modes(room).isEmpty {
        Text(verbatim: LiveTwitchChatText.modes(room).joined(separator: " · ")).font(TVType.label).foregroundStyle(TVPalette.textMid)
      }
      if model.chat.messages.isEmpty {
        Text(model.status == .live ? "No messages yet" : "Connecting to the live chat").font(TVType.meta).foregroundStyle(TVPalette.textMid)
        Spacer(minLength: 0)
      } else {
        TVNewestThatFit(spacing: 10) {
          ForEach(model.chat.messages) { event in
            Text(TVTwitchChatLine.event(event, emotes: model.emotes, selfLogin: model.account?.login ?? ""))
              .font(TVType.body)
              .lineLimit(3)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
      }
    }
  }
}

struct TVTwitchReplayLines: View {
  @ObservedObject var controller: LivePlayerController
  @ObservedObject var model: LiveTwitchVodChatViewModel

  var body: some View {
    let comments = model.window.visibleComments(at: controller.position)
    VStack(alignment: .leading, spacing: 14) {
      TVTwitchChatHeader(title: "CHAT REPLAY", active: !model.unavailable)
      if model.unavailable || comments.isEmpty {
        Text(model.unavailable ? "The chat replay of this video is not available." : "No messages at this point of the video.")
          .font(TVType.meta).foregroundStyle(TVPalette.textMid)
        Spacer(minLength: 0)
      } else {
        TVNewestThatFit(spacing: 10) {
          ForEach(comments) { comment in
            Text(TVTwitchChatLine.comment(comment, emotes: model.emotes))
              .font(TVType.body)
              .lineLimit(3)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
      }
    }
    .task { await model.loadAssets() }
    .task(id: Int(controller.position)) { await model.follow(position: controller.position) }
  }
}

struct TVTwitchChatHeader: View {
  let title: LocalizedStringKey
  let active: Bool

  var body: some View {
    HStack(spacing: 10) {
      Circle().fill(active ? TVPalette.accent : TVPalette.textLow).frame(width: 10, height: 10)
      Text(title).font(TVType.label).tracking(3).foregroundStyle(TVPalette.textMid)
    }
  }
}

struct TVTwitchChatCard<Content: View>: View {
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 6) { content }
      .foregroundStyle(TVPalette.textHigh)
      .padding(14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(TVPalette.surfaceRaised, in: RoundedRectangle(cornerRadius: 14))
  }
}
