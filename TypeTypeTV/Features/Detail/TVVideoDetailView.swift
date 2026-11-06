import SwiftUI

struct TVVideoDetailView: View {
  @StateObject private var model: LiveVideoDetailViewModel
  @StateObject private var actions: LiveVideoQuickActionsViewModel
  @StateObject private var engagement: LiveVideoEngagementViewModel
  @State private var pickingPlaylist = false
  let refresh: Int
  let onPlay: (LiveVideoItem, Int64?) -> Void
  let onOpen: (LiveVideoItem) -> Void
  let onOpenChannel: (String) -> Void
  @FocusState private var focus: TVDetailFocus?

  init(
    video: LiveVideoItem,
    dependencies: AppDependencies,
    refresh: Int,
    onPlay: @escaping (LiveVideoItem, Int64?) -> Void,
    onOpen: @escaping (LiveVideoItem) -> Void,
    onOpenChannel: @escaping (String) -> Void
  ) {
    _model = StateObject(wrappedValue: LiveVideoDetailViewModel(video: video, dependencies: dependencies))
    _actions = StateObject(wrappedValue: LiveVideoQuickActionsViewModel(video: video, dependencies: dependencies))
    _engagement = StateObject(wrappedValue: LiveVideoEngagementViewModel(
      video: video, allowsSubscription: true, service: dependencies.subscriptionsService
    ))
    self.refresh = refresh
    self.onPlay = onPlay
    self.onOpen = onOpen
    self.onOpenChannel = onOpenChannel
  }

  var body: some View {
    ZStack(alignment: .topLeading) {
      TVBackdrop(video: model.video)
      ScrollView(.vertical) {
        VStack(alignment: .leading, spacing: 64) {
          TVDetailHeader(
            model: model, actions: actions, engagement: engagement, focus: $focus,
            onPlay: play, onPlaylists: { pickingPlaylist = true },
            onChannel: model.video.uploaderURL.isEmpty ? nil : { onOpenChannel(model.video.uploaderURL) }
          )
          if !model.chapters.isEmpty { chapters }
          related
        }
        .padding(.top, 40)
        .padding(.bottom, 112)
      }
      .scrollClipDisabled()
      .disabled(pickingPlaylist)
      if pickingPlaylist {
        TVPlaylistPicker(actions: actions) {
          pickingPlaylist = false
          Task { focus = .playlists }
        }
      }
    }
    .background(TVPalette.ink.ignoresSafeArea())
    .task {
      focus = .play
      async let details: Void = model.load()
      async let state: Void = actions.prepare()
      async let subscription: Void = engagement.prepare()
      _ = await (details, state, subscription)
    }
    .onChange(of: refresh) { _, _ in Task { await model.refreshProgress() } }
  }

  private func play() {
    onPlay(model.video, model.resumeFraction == nil ? nil : model.resumeSeconds)
  }

  private var chapters: some View {
    VStack(alignment: .leading, spacing: 24) {
      Text("CHAPTERS").font(TVType.label).tracking(3.6).foregroundStyle(TVPalette.textMid).padding(.leading, TVDimens.safeStart)
      ScrollView(.horizontal) {
        LazyHStack(alignment: .top, spacing: 40) {
          ForEach(model.chapters) { chapter in
            VStack(alignment: .leading, spacing: 16) {
              Button(action: play) {
                ZStack(alignment: .bottomLeading) {
                  TVRemoteImage(url: chapter.previewURL.flatMap(URL.init(string:)) ?? model.video.thumbnail)
                  Text(verbatim: TVTime.label(TimeInterval(chapter.startTimeSeconds)))
                    .font(TVType.label).padding(.horizontal, 12).padding(.vertical, 6)
                    .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 8)).padding(14)
                }
                .frame(width: 584, height: 328)
              }
              .buttonStyle(.card)
              .accessibilityLabel(Text(verbatim: "\(chapter.title), \(TVTime.label(TimeInterval(chapter.startTimeSeconds)))"))
              Text(verbatim: chapter.title).font(TVType.title).foregroundStyle(TVPalette.textHigh).lineLimit(2)
                .frame(width: 584, alignment: .leading).accessibilityHidden(true)
            }
          }
        }
        .padding(.horizontal, TVDimens.safeStart)
        .padding(.vertical, 24)
      }
      .scrollClipDisabled()
    }
    .focusSection()
  }

  @ViewBuilder
  private var related: some View {
    if let videos = model.related, !videos.isEmpty {
      TVShelfRow(shelf: LiveHomeShelf(id: "related", title: String(localized: "MORE LIKE THIS"), videos: videos), onOpen: onOpen)
    } else if model.related == nil {
      ProgressView().padding(.leading, TVDimens.safeStart)
    }
  }
}

private struct TVPlaylistPicker: View {
  @ObservedObject var actions: LiveVideoQuickActionsViewModel
  let onClose: () -> Void
  @FocusState private var focused: String?

  var body: some View {
    HStack {
      Spacer()
      VStack(alignment: .leading, spacing: 24) {
        Text("Add to a playlist").font(TVType.headline).foregroundStyle(TVPalette.textHigh)
        if actions.playlists.isEmpty {
          Text("You have no playlist yet.").font(TVType.body).foregroundStyle(TVPalette.textMid)
        }
        ScrollView(.vertical) {
          VStack(alignment: .leading, spacing: 14) {
            ForEach(actions.playlists) { playlist in
              Button {
                Task { await actions.addToPlaylist(playlist) }
                onClose()
              } label: {
                Label(playlist.name, systemImage: "music.note.list").frame(width: 560, alignment: .leading)
              }
              .buttonStyle(.tvPill)
              .focused($focused, equals: playlist.id)
            }
          }
          .padding(.vertical, 12)
        }
        .scrollClipDisabled()
      }
      .padding(.horizontal, 56)
      .padding(.top, 180)
      .padding(.bottom, 56)
      .frame(width: 760)
      .frame(maxHeight: .infinity, alignment: .top)
      .background(TVPalette.surface.opacity(0.96))
    }
    .ignoresSafeArea()
    .focusSection()
    .onExitCommand(perform: onClose)
    .onAppear { focused = actions.playlists.first?.id }
  }
}
