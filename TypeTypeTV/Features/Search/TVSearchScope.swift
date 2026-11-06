import SwiftUI

// The source and the kind of result, as the chips above the Android TV search: one source at a time, and kinds the
// server offers for it, with the chosen one underlined.
struct TVSearchScope: View {
  @ObservedObject var model: LiveSearchViewModel

  private static let kinds: Set<String> = ["videos", "playlists", "channels", "music_songs", "music_videos", "lives", "animes",
                                             "movies_and_tv"]

  var body: some View {
    ScrollView(.horizontal) {
      chips
        .padding(.horizontal, TVDimens.safeStart)
        .padding(.vertical, 24)
    }
    .scrollClipDisabled()
    .focusSection()
    .task(id: model.visibleContentFilters) {
      // Videos is the kind a search starts on, as on Android TV, when the server offers it.
      if model.selectedContentFilter == nil, let videos = model.visibleContentFilters.first(where: { Self.key($0) == "videos" }) {
        await model.selectContentFilter(videos.value)
      }
    }
  }

  private var chips: some View {
    HStack(spacing: 20) {
      ForEach(model.services, id: \.id) { service in
        Button(service.name) { Task { await model.selectService(service.id) } }
          .buttonStyle(service.id == model.selectedServiceID ? .tvPillEmphasized : .tvPill)
          .accessibilityAddTraits(service.id == model.selectedServiceID ? .isSelected : [])
      }
      Rectangle().fill(TVPalette.outline).frame(width: 2, height: 48).padding(.horizontal, 8)
      ForEach(model.visibleContentFilters.filter { Self.kinds.contains(Self.key($0)) }) { filter in
        let selected = filter.value == effectiveFilter
        Button {
          Task { await model.selectContentFilter(filter.value) }
        } label: {
          Label(Self.title(filter), systemImage: Self.icon(filter))
        }
        .buttonStyle(.tvPill)
        .overlay(alignment: .bottom) {
          Capsule().fill(selected ? TVPalette.accent : .clear).frame(width: 48, height: 6).offset(y: 18)
        }
        .accessibilityAddTraits(selected ? .isSelected : [])
      }
    }
  }

  private var effectiveFilter: String? { model.selectedContentFilter }

  static func key(_ filter: LiveSearchFilterOption) -> String {
    let raw = filter.label.split(separator: ":").last.map(String.init) ?? filter.label
    return raw.trimmingCharacters(in: .whitespaces)
  }

  private static func title(_ filter: LiveSearchFilterOption) -> LocalizedStringKey {
    switch key(filter) {
    case "videos": "Videos"
    case "playlists": "Playlists"
    case "channels": "Channels"
    case "music_songs": "Music: songs"
    case "music_videos": "Music: videos"
    case "lives": "Live"
    case "animes": "Anime"
    case "movies_and_tv": "Movies and TV"
    default: LocalizedStringKey(filter.displayName)
    }
  }

  private static func icon(_ filter: LiveSearchFilterOption) -> String {
    switch key(filter) {
    case "videos": "play.circle.fill"
    case "playlists": "list.bullet"
    case "channels": "person.crop.circle.fill"
    case "music_songs": "music.note"
    case "music_videos": "music.note.tv"
    case "lives": "dot.radiowaves.left.and.right"
    case "animes": "sparkles"
    case "movies_and_tv": "film"
    default: "line.3.horizontal.decrease.circle"
    }
  }
}
