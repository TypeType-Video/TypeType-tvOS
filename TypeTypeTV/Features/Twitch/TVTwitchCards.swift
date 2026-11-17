import SwiftUI

struct TVTwitchStreamCard: View {
  let stream: LiveTwitchStream
  var width: CGFloat = 520
  let onOpen: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Button(action: onOpen) {
        ZStack {
          TVRemoteImage(url: LiveImageURLResolver.resolve(stream.previewURL))
          TVTwitchTag(text: Text("LIVE"), tint: TVPalette.accent)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
          TVTwitchTag(text: Text("\(LiveTwitchFormat.count(stream.viewers)) watching"), tint: .black.opacity(0.72))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .frame(width: width, height: width * 9 / 16)
      }
      .buttonStyle(.card)
      .accessibilityLabel(Text("\(stream.user.name) live: \(stream.title)"))
      .accessibilityValue(Text("\(LiveTwitchFormat.count(stream.viewers)) watching"))
      VStack(alignment: .leading, spacing: 4) {
        Text(verbatim: stream.title)
          .font(TVType.title)
          .foregroundStyle(TVPalette.textHigh)
          .lineLimit(1)
        Text(verbatim: [stream.user.name, stream.game?.name].compactMap { $0 }.joined(separator: " · "))
          .font(TVType.meta)
          .foregroundStyle(TVPalette.textMid)
          .lineLimit(1)
      }
      .frame(width: width, alignment: .leading)
      .accessibilityHidden(true)
    }
  }
}

struct TVTwitchGameCard: View {
  let game: LiveTwitchGame
  let onOpen: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Button(action: onOpen) {
        TVRemoteImage(url: LiveImageURLResolver.resolve(game.boxArtURL))
          .frame(width: 228, height: 304)
      }
      .buttonStyle(.card)
      .accessibilityLabel(Text(verbatim: game.name))
      .accessibilityHint(Text("Shows the lives in this category."))
      VStack(alignment: .leading, spacing: 4) {
        Text(verbatim: game.name)
          .font(TVType.meta)
          .foregroundStyle(TVPalette.textHigh)
          .lineLimit(1)
        if let viewers = game.viewers {
          Text("\(LiveTwitchFormat.count(viewers)) watching")
            .font(TVType.label)
            .foregroundStyle(TVPalette.textMid)
        }
      }
      .frame(width: 228, alignment: .leading)
      .accessibilityHidden(true)
    }
  }
}

struct TVTwitchMediaTile: View {
  let title: String
  let previewURL: String
  let duration: Int
  let detail: String
  var width: CGFloat = 440
  let onOpen: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      Button(action: onOpen) {
        ZStack {
          TVRemoteImage(url: LiveImageURLResolver.resolve(previewURL))
          if duration > 0 {
            TVTwitchTag(text: Text(verbatim: LiveVideoMetadataFormatter.duration(Int64(duration))), tint: .black.opacity(0.72))
              .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
          }
        }
        .frame(width: width, height: width * 9 / 16)
      }
      .buttonStyle(.card)
      .accessibilityLabel(Text(verbatim: title))
      .accessibilityValue(Text(verbatim: detail))
      VStack(alignment: .leading, spacing: 4) {
        Text(verbatim: title)
          .font(TVType.meta)
          .foregroundStyle(TVPalette.textHigh)
          .lineLimit(2)
        Text(verbatim: detail)
          .font(TVType.label)
          .foregroundStyle(TVPalette.textMid)
      }
      .frame(width: width, alignment: .leading)
      .accessibilityHidden(true)
    }
  }
}

struct TVTwitchTag: View {
  let text: Text
  let tint: Color

  var body: some View {
    text
      .font(TVType.label)
      .foregroundStyle(TVPalette.textHigh)
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .background(tint, in: RoundedRectangle(cornerRadius: 8))
      .padding(14)
  }
}

struct TVTwitchSectionTitle: View {
  let title: LocalizedStringKey

  var body: some View {
    Text(title)
      .textCase(.uppercase)
      .font(TVType.label)
      .tracking(3.6)
      .foregroundStyle(TVPalette.textMid)
  }
}
