import SwiftUI

struct TVAudioTrack: Identifiable {
  let id: String
  let label: String
  let original: Bool
  let sourceID: String
}

extension LivePlayerController {
  // One entry a language: the sources of a track differ only by bitrate, so the best one stands for it. Android TV's
  // AudioChoices order: the original first, then by name.
  var audioTracks: [TVAudioTrack] {
    let byTrack = Dictionary(grouping: availableAudioSources.filter { $0.audioTrackID != nil }) { $0.audioTrackID ?? "" }
    return byTrack.compactMap { id, sources in
      guard let best = sources.max(by: { ($0.bitrate ?? 0) < ($1.bitrate ?? 0) }) else { return nil }
      let name = best.audioTrackName ?? best.audioLocale.flatMap { Locale.current.localizedString(forIdentifier: $0) } ?? id
      return TVAudioTrack(id: id, label: name, original: sources.contains(where: \.isOriginal), sourceID: best.id)
    }
    .sorted { ($0.original ? 0 : 1, $0.label.lowercased()) < ($1.original ? 0 : 1, $1.label.lowercased()) }
  }

  var currentAudioTrack: TVAudioTrack? {
    let tracks = audioTracks
    return tracks.first { $0.id == selectedAudioTrackID } ?? tracks.first { $0.original } ?? tracks.first
  }
}

// Android TV's AudioOnlyPoster: the video's picture dimmed behind headphones while only the sound plays.
struct TVAudioOnlyPoster: View {
  let video: LiveVideoItem

  var body: some View {
    ZStack {
      Color.black
      TVRemoteImage(url: video.thumbnail).opacity(0.28)
      VStack(spacing: 24) {
        Image(systemName: "headphones").font(.system(size: 144))
        Text("Audio only").font(TVType.headline)
      }
      .foregroundStyle(TVPalette.textHigh)
    }
    .ignoresSafeArea()
    .accessibilityElement(children: .combine)
  }
}
