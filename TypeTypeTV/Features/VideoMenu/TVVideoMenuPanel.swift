import SwiftUI

struct TVVideoMenuPanel: View {
  @StateObject private var actions: LiveVideoQuickActionsViewModel
  @StateObject private var blocking: LiveVideoBlocking
  @State private var pickingPlaylist = false
  @State private var removeFailed = false
  @FocusState private var focus: String?
  let video: LiveVideoItem
  let playlist: TVMenuPlaylist?
  let onPlay: () -> Void
  let onOpenChannel: () -> Void
  let onClose: () -> Void

  init(
    request: TVVideoMenuRequest, dependencies: AppDependencies, onPlay: @escaping () -> Void,
    onOpenChannel: @escaping () -> Void, onClose: @escaping () -> Void
  ) {
    let video = request.video
    _actions = StateObject(wrappedValue: LiveVideoQuickActionsViewModel(video: video, dependencies: dependencies))
    _blocking = StateObject(wrappedValue: LiveVideoBlocking(
      video: video, service: dependencies.contentControlsService, hidden: dependencies.hiddenVideos
    ))
    self.video = video
    playlist = request.playlist
    self.onPlay = onPlay
    self.onOpenChannel = onOpenChannel
    self.onClose = onClose
  }

  var body: some View {
    ZStack(alignment: .trailing) {
      TVPalette.ink.opacity(0.8).ignoresSafeArea()
      VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 28) {
          TVRemoteImage(url: video.thumbnail).frame(width: 256, height: 144)
            .clipShape(RoundedRectangle(cornerRadius: TVDimens.cardRadius))
          VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: video.title).font(TVType.title).foregroundStyle(TVPalette.textHigh).lineLimit(2)
            Text(verbatim: video.uploaderName).font(TVType.meta).foregroundStyle(TVPalette.textMid).lineLimit(1)
          }
        }
        .accessibilityElement(children: .combine)
        .padding(.bottom, 16)
        row("play", "Play", "play.fill", perform: onPlay)
        if !video.uploaderURL.isEmpty { row("channel", "Open channel", "person.crop.circle", perform: onOpenChannel) }
        row("playlists", "Add to a playlist", "text.badge.plus") { pickingPlaylist = true }
          .disabled(!actions.isPrepared)
        if let playlist {
          row("remove", "Remove from \(playlist.name)", "text.badge.minus") {
            Task {
              removeFailed = !(await actions.removeFromPlaylist(id: playlist.id))
              guard !removeFailed else { return }
              playlist.onRemoved(video)
              onClose()
            }
          }
          .disabled(actions.isBusy)
        }
        row("later", actions.isInWatchLater ? "Remove from Watch later" : "Add to Watch later",
            actions.isInWatchLater ? "bookmark.fill" : "bookmark") { Task { await actions.toggleWatchLater() } }
          .disabled(!actions.isPrepared || actions.isBusy)
        row("favorite", actions.isFavorite ? "Remove from Favorites" : "Add to Favorites",
            actions.isFavorite ? "heart.fill" : "heart") { Task { await actions.toggleFavorite() } }
          .disabled(!actions.isPrepared || actions.isBusy)
        row("block-video", blocking.videoBlocked ? "Unblock this video" : "Block this video", "nosign") {
          Task { await blocking.setVideoBlocked(!blocking.videoBlocked) }
        }
        .disabled(!blocking.isLoaded)
        .padding(.top, 12)
        if !video.uploaderURL.isEmpty {
          row("block-channel", blocking.channelBlocked ? "Unblock this channel" : "Block this channel",
              "person.crop.circle.badge.xmark") { Task { await blocking.setChannelBlocked(!blocking.channelBlocked) } }
            .disabled(!blocking.isLoaded)
        }
        if blocking.failed || removeFailed {
          Text("The action could not be completed.").font(TVType.meta).foregroundStyle(TVPalette.accent).padding(.top, 8)
        }
        Spacer(minLength: 0)
      }
      .opacity(pickingPlaylist ? 0 : 1)
      .padding(.leading, 56).padding(.trailing, TVDimens.safeStart).padding(.top, 90).padding(.bottom, 60)
      .frame(width: 880)
      .frame(maxHeight: .infinity, alignment: .top)
      .background(TVPalette.surface)
      .focusSection()
      .disabled(pickingPlaylist)
      if pickingPlaylist {
        TVPlaylistPicker(actions: actions) {
          pickingPlaylist = false
          Task { focus = "playlists" }
        }
      }
    }
    .ignoresSafeArea()
    .onExitCommand { if !pickingPlaylist { onClose() } }
    .task {
      focus = "play"
      async let prepared: Void = actions.prepare()
      async let loaded: Void = blocking.load()
      _ = await (prepared, loaded)
    }
  }

  private func row(
    _ key: String, _ title: LocalizedStringKey, _ systemImage: String, perform: @escaping () -> Void
  ) -> some View {
    Button(action: perform) {
      Label(title, systemImage: systemImage).frame(maxWidth: .infinity, alignment: .leading)
    }
    .buttonStyle(.tvPill)
    .focused($focus, equals: key)
  }
}
