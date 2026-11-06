import SwiftUI

struct TVVideoDetailView: View {
  @StateObject private var model: LiveVideoDetailViewModel
  @StateObject private var actions: LiveVideoQuickActionsViewModel
  let onPlay: (LiveVideoItem, Int64?) -> Void
  let onOpen: (LiveVideoItem) -> Void
  @FocusState private var playFocused: Bool

  init(
    video: LiveVideoItem,
    dependencies: AppDependencies,
    onPlay: @escaping (LiveVideoItem, Int64?) -> Void,
    onOpen: @escaping (LiveVideoItem) -> Void
  ) {
    _model = StateObject(wrappedValue: LiveVideoDetailViewModel(video: video, dependencies: dependencies))
    _actions = StateObject(wrappedValue: LiveVideoQuickActionsViewModel(video: video, dependencies: dependencies))
    self.onPlay = onPlay
    self.onOpen = onOpen
  }

  var body: some View {
    ZStack(alignment: .topLeading) {
      TVBackdrop(video: model.video)
      ScrollView(.vertical) {
        VStack(alignment: .leading, spacing: 64) {
          TVDetailHeader(model: model, actions: actions, playFocused: $playFocused) {
            onPlay(model.video, model.resumeFraction == nil ? nil : model.resumeSeconds)
          }
          related
        }
        .padding(.top, 40)
        .padding(.bottom, 112)
      }
      .scrollClipDisabled()
    }
    .background(TVPalette.ink.ignoresSafeArea())
    .task {
      playFocused = true
      async let details: Void = model.load()
      async let state: Void = actions.prepare()
      _ = await (details, state)
    }
  }

  @ViewBuilder
  private var related: some View {
    if let videos = model.related, !videos.isEmpty {
      TVShelfRow(
        shelf: LiveHomeShelf(id: "related", title: String(localized: "MORE LIKE THIS"), videos: videos),
        onOpen: onOpen
      )
    } else if model.related == nil {
      ProgressView().padding(.leading, TVDimens.safeStart)
    }
  }
}

private struct TVDetailHeader: View {
  @ObservedObject var model: LiveVideoDetailViewModel
  @ObservedObject var actions: LiveVideoQuickActionsViewModel
  var playFocused: FocusState<Bool>.Binding
  let onPlay: () -> Void

  var body: some View {
    let video = model.video
    VStack(alignment: .leading, spacing: 20) {
      if let service = VideoService.hosting(video.url) {
        Text(verbatim: service.name.uppercased())
          .font(TVType.label)
          .tracking(3.6)
          .foregroundStyle(TVPalette.accent)
      }
      Text(verbatim: video.title)
        .font(TVType.display)
        .foregroundStyle(TVPalette.textHigh)
        .lineLimit(2)
        .frame(width: 1000, alignment: .leading)
      Text(verbatim: meta(video))
        .font(TVType.meta)
        .foregroundStyle(TVPalette.textMid)
      channel(video)
      Text(verbatim: model.description)
        .font(TVType.body)
        .foregroundStyle(TVPalette.textMid)
        .lineLimit(3)
        .frame(width: 1000, alignment: .leading)
      if let fraction = model.resumeFraction, let seconds = model.resumeSeconds {
        HStack(spacing: 20) {
          Capsule().fill(TVPalette.outline).frame(width: 240, height: 6)
            .overlay(alignment: .leading) { Capsule().fill(TVPalette.accent).frame(width: 240 * fraction, height: 6) }
          Text("\(LiveVideoMetadataFormatter.duration(max(video.duration - seconds, 0))) left")
            .font(TVType.meta)
            .foregroundStyle(TVPalette.textMid)
        }
        .accessibilityElement(children: .combine)
      }
      buttons(video)
        .padding(.top, 16)
    }
    .padding(.leading, TVDimens.safeStart)
  }

  private func buttons(_ video: LiveVideoItem) -> some View {
    HStack(spacing: 20) {
      Button(action: onPlay) {
        Label(playTitle(video), systemImage: "play.fill")
      }
      .buttonStyle(.tvPillEmphasized)
      .focused(playFocused)
      Button {
        Task { await actions.toggleWatchLater() }
      } label: {
        Label(actions.isInWatchLater ? "Saved" : "Watch later", systemImage: actions.isInWatchLater ? "bookmark.fill" : "bookmark")
      }
      .buttonStyle(.tvPill)
      .disabled(!actions.isPrepared || actions.isBusy)
      Button {
        Task { await actions.toggleFavorite() }
      } label: {
        Label(actions.isFavorite ? "Favorited" : "Favorite", systemImage: actions.isFavorite ? "heart.fill" : "heart")
      }
      .buttonStyle(.tvPill)
      .disabled(!actions.isPrepared || actions.isBusy)
    }
  }

  private func playTitle(_ video: LiveVideoItem) -> LocalizedStringKey {
    if video.isLive { return "Watch live" }
    return model.resumeFraction == nil ? "Play" : "Resume"
  }

  private func channel(_ video: LiveVideoItem) -> some View {
    HStack(spacing: 20) {
      TVRemoteImage(url: video.uploaderAvatar)
        .frame(width: 64, height: 64)
        .clipShape(Circle())
      VStack(alignment: .leading, spacing: 4) {
        Text(verbatim: video.uploaderName)
          .font(TVType.title)
          .foregroundStyle(TVPalette.textHigh)
        if let count = model.subscriberCount {
          Text(verbatim: LiveVideoMetadataFormatter.subscribers(count))
            .font(TVType.meta)
            .foregroundStyle(TVPalette.textMid)
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
