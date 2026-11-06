import SwiftUI

enum TVDetailFocus: Hashable {
  case play
  case playlists
}

struct TVDetailHeader: View {
  @ObservedObject var model: LiveVideoDetailViewModel
  @ObservedObject var actions: LiveVideoQuickActionsViewModel
  @ObservedObject var engagement: LiveVideoEngagementViewModel
  var focus: FocusState<TVDetailFocus?>.Binding
  let onPlay: () -> Void
  let onPlaylists: () -> Void
  let onChannel: (() -> Void)?

  var body: some View {
    let video = model.video
    VStack(alignment: .leading, spacing: 20) {
      if let label = model.category ?? VideoService.hosting(video.url)?.name {
        Text(verbatim: label.uppercased()).font(TVType.label).tracking(3.6).foregroundStyle(TVPalette.accent)
      }
      Text(verbatim: video.title)
        .font(TVType.display).foregroundStyle(TVPalette.textHigh).lineLimit(2)
        .frame(width: 1000, alignment: .leading)
      HStack(spacing: 20) {
        if let service = VideoService.hosting(video.url) { TVBadge(text: service.name, tone: .service) }
        if video.isLive { TVBadge(text: String(localized: "LIVE"), tone: .service) }
        if let height = model.bestHeight, height >= 720 { TVBadge(text: height >= 2_160 ? "4K" : "HD", tone: .plain) }
        Text(verbatim: meta(video)).font(TVType.meta).foregroundStyle(TVPalette.textMid)
      }
      channel(video)
      Text(verbatim: model.description)
        .font(TVType.body).foregroundStyle(TVPalette.textMid).lineLimit(3)
        .frame(width: 1000, alignment: .leading)
      if let fraction = model.resumeFraction, let seconds = model.resumeSeconds {
        HStack(spacing: 20) {
          Capsule().fill(TVPalette.outline).frame(width: 240, height: 6)
            .overlay(alignment: .leading) { Capsule().fill(TVPalette.accent).frame(width: 240 * fraction, height: 6) }
          Text("\(LiveVideoMetadataFormatter.duration(max(video.duration - seconds, 0))) left")
            .font(TVType.meta).foregroundStyle(TVPalette.textMid)
        }
        .accessibilityElement(children: .combine)
      }
      buttons(video).padding(.top, 16)
    }
    .padding(.leading, TVDimens.safeStart)
  }

  private func buttons(_ video: LiveVideoItem) -> some View {
    HStack(spacing: 20) {
      Button(action: onPlay) { Label(playTitle(video), systemImage: "play.fill") }
        .buttonStyle(.tvPillEmphasized)
        .focused(focus, equals: .play)
      toggle(actions.isInWatchLater, on: ("Saved", "bookmark.fill"), off: ("Watch later", "bookmark")) {
        Task { await actions.toggleWatchLater() }
      }
      .disabled(!actions.isPrepared || actions.isBusy)
      toggle(actions.isFavorite, on: ("Favorited", "heart.fill"), off: ("Favorite", "heart")) {
        Task { await actions.toggleFavorite() }
      }
      .disabled(!actions.isPrepared || actions.isBusy)
      if engagement.canSubscribe {
        toggle(engagement.isSubscribed, on: ("Subscribed", "checkmark"), off: ("Subscribe", "bell")) {
          Task { await engagement.toggleSubscription() }
        }
        .disabled(engagement.isLoading || engagement.isChanging)
      }
      Button(action: onPlaylists) { Label("Playlists", systemImage: "text.badge.plus") }
        .buttonStyle(.tvPill)
        .focused(focus, equals: .playlists)
        .disabled(!actions.isPrepared)
      if let onChannel {
        Button(action: onChannel) { Label("Channel", systemImage: "person.crop.circle") }
          .buttonStyle(.tvPill)
      }
    }
  }

  private func toggle(
    _ isOn: Bool, on: (LocalizedStringKey, String), off: (LocalizedStringKey, String), action: @escaping () -> Void
  ) -> some View {
    Button(action: action) { Label(isOn ? on.0 : off.0, systemImage: isOn ? on.1 : off.1) }
      .buttonStyle(.tvPill)
  }

  private func playTitle(_ video: LiveVideoItem) -> LocalizedStringKey {
    if video.isLive { return "Watch live" }
    return model.resumeFraction == nil ? "Play" : "Resume"
  }

  private func channel(_ video: LiveVideoItem) -> some View {
    HStack(spacing: 20) {
      TVRemoteImage(url: video.uploaderAvatar).frame(width: 64, height: 64).clipShape(Circle())
      VStack(alignment: .leading, spacing: 4) {
        Text(verbatim: video.uploaderName).font(TVType.title).foregroundStyle(TVPalette.textHigh)
        if let count = model.subscriberCount {
          Text(verbatim: LiveVideoMetadataFormatter.subscribers(count)).font(TVType.meta).foregroundStyle(TVPalette.textMid)
        }
      }
    }
    .accessibilityElement(children: .combine)
  }

  private func meta(_ video: LiveVideoItem) -> String {
    var parts: [String] = []
    if video.viewCount > 0 { parts.append(LiveVideoMetadataFormatter.views(video.viewCount)) }
    let published = LiveVideoMetadataFormatter.publication(video)
    if !published.isEmpty { parts.append(published) }
    if video.duration > 0 { parts.append(LiveVideoMetadataFormatter.duration(video.duration)) }
    return parts.joined(separator: " · ")
  }
}
