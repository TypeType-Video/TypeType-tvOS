import SwiftUI

enum TVTwitchChatLine {
  static func event(_ event: LiveTwitchChatEvent, emotes: [String: LiveTwitchThirdPartyEmote], selfLogin: String) -> AttributedString {
    guard event.kind == .message, let text = event.text else {
      var line = AttributedString(event.system ?? event.text ?? "")
      line.foregroundColor = TVPalette.textMid
      return line
    }
    var line = author(event.author, login: event.login ?? event.author, color: event.color)
    if event.deleted {
      var deleted = AttributedString(String(localized: "Message deleted by a moderator"))
      deleted.foregroundColor = TVPalette.textLow
      return line + deleted
    }
    line += body(LiveTwitchChatParts.parts(text: text, native: event.emotes, emotes: emotes, selfLogin: selfLogin))
    return line
  }

  static func comment(_ comment: LiveTwitchVideoComment, emotes: [String: LiveTwitchThirdPartyEmote]) -> AttributedString {
    author(comment.author, login: comment.login ?? comment.author, color: comment.color) + body(LiveTwitchChatParts.parts(text: comment.text, native: comment.emotes ?? [], emotes: emotes))
  }

  private static func author(_ name: String, login: String, color: String?) -> AttributedString {
    var author = AttributedString(name + "  ")
    author.foregroundColor = LiveTwitchChatText.nameColor(color, login: login, dark: true)
    return author
  }

  private static func body(_ parts: [LiveTwitchChatPart]) -> AttributedString {
    parts.reduce(into: AttributedString()) { line, part in
      var piece: AttributedString
      switch part {
      case let .text(text):
        piece = AttributedString(text)
        piece.foregroundColor = TVPalette.textHigh
      case let .emote(image, overlays):
        piece = AttributedString(([image] + overlays).map(\.name).joined(separator: " "))
        piece.foregroundColor = TVPalette.accentSoft
      case let .link(text, _):
        piece = AttributedString(text)
        piece.foregroundColor = TVPalette.textMid
      case let .mention(text, isSelf):
        piece = AttributedString(text)
        piece.foregroundColor = isSelf ? TVPalette.accent : TVPalette.textHigh
      }
      line += piece
    }
  }
}
