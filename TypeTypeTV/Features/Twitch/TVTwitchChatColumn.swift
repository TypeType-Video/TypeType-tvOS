import SwiftUI

struct TVTwitchChatColumn: View {
  @ObservedObject var controller: LivePlayerController
  let chat: TVTwitchChat
  let layout: TVChatLayout
  let density: TVChatDensity
  let dimmed: Bool

  var body: some View {
    TVChatSurface(layout: layout, dimmed: dimmed) {
      if let live = chat.live {
        TVTwitchLiveChatLines(model: live, density: density)
      } else if let replay = chat.replay {
        TVTwitchReplayLines(controller: controller, model: replay, density: density)
      }
    }
  }
}

struct TVTwitchLiveChatLines: View {
  @ObservedObject var model: LiveTwitchChatViewModel
  let density: TVChatDensity

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      TVTwitchChatHeader(title: "LIVE CHAT", active: model.status == .live)
      if let pinned = model.visiblePinned {
        TVTwitchPinnedCard(pinned: pinned)
      }
      if let poll = model.visiblePoll {
        TVTwitchPollCard(poll: poll)
      }
      if let room = model.chat.room, !LiveTwitchChatText.modes(room).isEmpty {
        Text(verbatim: LiveTwitchChatText.modes(room).joined(separator: " · ")).font(TVType.label).foregroundStyle(TVPalette.textMid)
      }
      if model.chat.messages.isEmpty {
        Text(model.status == .live ? "No messages yet" : "Connecting to the live chat").font(TVType.meta).foregroundStyle(TVPalette.textMid)
        Spacer(minLength: 0)
      } else {
        TVNewestThatFit(spacing: density.spacing) {
          ForEach(model.chat.messages) { event in
            if event.kind == .message, let text = event.text {
              TVTwitchChatMessage(
                author: event.author, login: event.login ?? event.author, color: event.color,
                badges: event.badges.compactMap { model.badges[$0] },
                parts: LiveTwitchChatParts.parts(text: text, native: event.emotes, emotes: model.emotes, selfLogin: model.account?.login ?? ""),
                density: density,
                deleted: event.deleted
              )
            } else {
              TVTwitchSystemLine(text: event.system ?? event.text ?? "", density: density)
            }
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
  let density: TVChatDensity

  var body: some View {
    let comments = model.window.visibleComments(at: controller.position)
    VStack(alignment: .leading, spacing: 14) {
      TVTwitchChatHeader(title: "CHAT REPLAY", active: !model.unavailable)
      if model.unavailable || comments.isEmpty {
        (model.unavailable ? Text("The chat replay of this video is not available.") : Text("No messages at this point of the video."))
          .font(TVType.meta).foregroundStyle(TVPalette.textMid)
        Spacer(minLength: 0)
      } else {
        TVNewestThatFit(spacing: density.spacing) {
          ForEach(comments) { comment in
            TVTwitchChatMessage(
              author: comment.author, login: comment.login ?? comment.author, color: comment.color,
              badges: (comment.badges ?? []).compactMap { model.badges[$0] },
              parts: LiveTwitchChatParts.parts(text: comment.text, native: comment.emotes ?? [], emotes: model.emotes),
              density: density
            )
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
