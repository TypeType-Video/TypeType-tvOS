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
  @EnvironmentObject private var account: TVAccountSettings
  @Environment(\.dismiss) private var dismiss

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
      .tvReportsScroll()
      .disabled(pickingPlaylist)
      if pickingPlaylist {
        TVPlaylistPicker(actions: actions) { closePlaylistPicker() }
      }
    }
    .tvContentEdges()
    // Menu closes the picker only. Without a handler here the stack popped a whole route while the picker was open,
    // so the picker took the video page with it.
    .onExitCommand {
      if pickingPlaylist {
        closePlaylistPicker()
      } else {
        dismiss()
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

  private func closePlaylistPicker() {
    pickingPlaylist = false
    Task { focus = .playlists }
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
    if account.hidesRelated {
      EmptyView()
    } else if let videos = model.related, !videos.isEmpty {
      TVShelfRow(shelf: LiveHomeShelf(id: "related", title: String(localized: "MORE LIKE THIS"), videos: videos), onOpen: onOpen)
    } else if model.related == nil {
      // Android's RelatedSkeleton: the cards of the row before they arrive.
      HStack(spacing: 40) {
        ForEach(0..<5, id: \.self) { _ in
          VStack(alignment: .leading, spacing: 20) {
            RoundedRectangle(cornerRadius: TVDimens.cardRadius).fill(TVPalette.surfaceRaised).frame(width: 392, height: 220)
            Capsule().fill(TVPalette.surfaceRaised).frame(width: 300, height: 24)
          }
        }
      }
      .frame(width: 1808, alignment: .leading)
      .padding(.leading, TVDimens.safeStart)
      .accessibilityHidden(true)
    }
  }
}

struct TVPlaylistPicker: View {
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
      // 90 below the container: the column starts below the tab bar (see below), so the old 180 would sit a bar height
      // too low.
      .padding(.top, 90)
      .padding(.bottom, 56)
      .frame(width: 760)
      .frame(maxHeight: .infinity, alignment: .top)
      .background(TVPalette.surface.opacity(0.96))
    }
    // The column is cut off under the top bar: it keeps the horizontal and bottom bleed but takes the top safe area, and
    // the clip keeps list rows from drawing over the tab bar (the playlist list scrolls with clipping disabled).
    .ignoresSafeArea(edges: [.horizontal, .bottom])
    .clipShape(Rectangle())
    .focusSection()
    .onAppear { focused = actions.playlists.first?.id }
  }
}
