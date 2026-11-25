import SwiftUI

struct TVTwitchChatMessage: View {
  let author: String
  let login: String
  let color: String?
  let badges: [LiveTwitchChatBadge]
  let parts: [LiveTwitchChatPart]
  var density = TVChatDensity.medium
  var deleted = false

  var body: some View {
    LiveTwitchFlowLayout(spacing: 6, lineSpacing: 6) {
      ForEach(Array(badges.enumerated()), id: \.offset) { _, badge in
        TVRemoteImage(url: URL(string: badge.url2x ?? badge.url), size: .card, placeholder: false)
          .frame(width: density.badge, height: density.badge)
      }
      Text(verbatim: author)
        .font(density.font.weight(.semibold))
        .foregroundStyle(LiveTwitchChatText.nameColor(color, login: login, dark: true))
      if deleted {
        Text("Message deleted by a moderator").font(density.font).foregroundStyle(TVPalette.textLow)
      } else {
        ForEach(Array(tokens.enumerated()), id: \.offset) { _, token in
          view(token)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private enum Token {
    case word(String, Color)
    case emote([LiveTwitchEmoteImage])
  }

  private var tokens: [Token] {
    parts.flatMap { part -> [Token] in
      switch part {
      case let .text(text): text.split(whereSeparator: \.isWhitespace).map { .word(String($0), TVPalette.textHigh) }
      case let .emote(image, overlays): [.emote([image] + overlays)]
      case let .link(text, _): [.word(text, TVPalette.textMid)]
      case let .mention(text, isSelf): [.word(text, isSelf ? TVPalette.accent : TVPalette.textHigh)]
      }
    }
  }

  @ViewBuilder
  private func view(_ token: Token) -> some View {
    switch token {
    case let .word(word, tint):
      Text(verbatim: word).font(density.font).foregroundStyle(tint)
    case let .emote(images):
      ZStack {
        ForEach(Array(images.enumerated()), id: \.offset) { _, image in
          TVRemoteImage(url: image.url, size: .card, placeholder: false)
        }
      }
      .frame(width: density.emote, height: density.emote)
    }
  }
}

struct TVTwitchSystemLine: View {
  let text: String
  var density = TVChatDensity.medium

  var body: some View {
    Text(verbatim: text).font(density.font).foregroundStyle(TVPalette.textMid).frame(maxWidth: .infinity, alignment: .leading)
  }
}
