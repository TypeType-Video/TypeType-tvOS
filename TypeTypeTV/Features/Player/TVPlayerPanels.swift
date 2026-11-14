import SwiftUI

struct TVPlayerPanel: View {
  @ObservedObject var controller: LivePlayerController
  @ObservedObject var session: TVPlayerSession
  @ObservedObject var actions: LiveVideoQuickActionsViewModel
  @ObservedObject var engagement: LiveVideoEngagementViewModel
  let comments: LiveCommentsViewModel
  let threads: LiveCommentThreads
  let voice: LiveCommentVoicePlayer
  let panel: TVPlayerSession.Panel
  var queue: [LiveVideoItem] = []
  var onOpen: (LiveVideoItem) -> Void = { _ in }
  @FocusState private var choiceFocus: String?

  private static let speeds: [Float] = [0.5, 0.75, 1, 1.25, 1.5, 2]

  var body: some View {
    HStack {
      Spacer()
      VStack(alignment: .leading, spacing: 24) {
        Text(title)
          .font(TVType.headline)
          .foregroundStyle(TVPalette.textHigh)
        ScrollView(.vertical) {
          LazyVStack(alignment: .leading, spacing: 14) { rows }
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
        }
        .padding(.horizontal, -12)
      }
      .padding(.horizontal, 56)
      .padding(.top, 90)
      .padding(.bottom, 56)
      .frame(width: 760)
      .frame(maxHeight: .infinity, alignment: .top)
      .background(TVPalette.surface.opacity(0.96))
    }
    .ignoresSafeArea()
    .focusSection()
    .task(id: "\(panel) \(preferredChoice ?? "")") {
      guard choiceFocus == nil, let preferred = preferredChoice,
        (try? await Task.sleep(for: .milliseconds(60))) != nil
      else { return }
      choiceFocus = preferred
    }
  }

  private var preferredChoice: String? {
    switch panel {
    case .playlists: actions.playlists.first?.name
    case .quality:
      controller.selectedVideoSourceID == nil
        ? String(localized: "Auto")
        : LivePlaybackVideoCatalog.resolutionOptions(from: controller.availableVideoSources).first(where: isSelected)
          .map(LivePlaybackVideoCatalog.qualityLabel(for:))
    case .audio: controller.audioTracks.first { $0.id == controller.currentAudioTrack?.id }.map(audioLabel)
    case .speed: speedLabel(Self.speeds.first { $0 == controller.playbackRate } ?? 1)
    default: nil
    }
  }

  private func audioLabel(_ track: TVAudioTrack) -> String {
    track.original && !track.label.localizedCaseInsensitiveContains(String(localized: "Original"))
      ? "\(track.label) · \(String(localized: "Original"))" : track.label
  }

  private func speedLabel(_ speed: Float) -> String {
    speed == 1 ? String(localized: "Normal") : "\(speed.formatted())×"
  }

  private var title: LocalizedStringKey {
    switch panel {
    case .menu: "Player options"
    case .chapters: "Chapters"
    case .quality: "Quality"
    case .audio: "Audio language"
    case .speed: "Playback speed"
    case .playlists: "Add to a playlist"
    case .comments: "Comments"
    case .queue: "Up next"
    case .captionStyle: "Subtitle style"
    case .info: "Description"
    case .channel: ""
    }
  }

  @ViewBuilder
  private var rows: some View {
    switch panel {
    case .menu:
      TVPlayerMenuRows(controller: controller, session: session, actions: actions, engagement: engagement, queueCount: queue.count)
    case .chapters:
      TVPlayerChapterRows(controller: controller, session: session)
    case .comments:
      TVCommentRows(comments: comments, threads: threads, voice: voice)
    case .captionStyle:
      TVCaptionStyleRows(controller: controller)
    case .queue:
      TVQueueRows(videos: queue) { video in
        session.closePanel()
        onOpen(video)
      }
    case .playlists:
      if actions.playlists.isEmpty {
        Text("You have no playlist yet.").font(TVType.body).foregroundStyle(TVPalette.textMid)
      }
      ForEach(actions.playlists) { playlist in
        choice(playlist.name, selected: false) { Task { await actions.addToPlaylist(playlist) } }
      }
    case .quality:
      choice(String(localized: "Auto"), selected: controller.selectedVideoSourceID == nil) {
        controller.selectVideoResolution(nil)
      }
      ForEach(LivePlaybackVideoCatalog.resolutionOptions(from: controller.availableVideoSources).reversed(), id: \.selectionID) { source in
        choice(LivePlaybackVideoCatalog.qualityLabel(for: source), selected: isSelected(source)) {
          controller.selectVideoResolution(source.effectiveHeight)
        }
      }
    case .audio:
      ForEach(controller.audioTracks) { track in
        choice(audioLabel(track), selected: track.id == controller.currentAudioTrack?.id) {
          if track.id != controller.currentAudioTrack?.id { controller.selectAudioSource(track.sourceID) }
        }
      }
    case .speed:
      ForEach(Self.speeds, id: \.self) { speed in
        choice(speedLabel(speed), selected: controller.playbackRate == speed) {
          controller.setPlaybackRate(speed)
        }
      }
    case .channel:
      EmptyView()
    case .info:
      Text(verbatim: controller.video.title).font(TVType.title).foregroundStyle(TVPalette.textHigh)
      Text(verbatim: controller.video.uploaderName).font(TVType.meta).foregroundStyle(TVPalette.textMid)
      Text(verbatim: controller.stream?.description ?? controller.video.shortDescription ?? "")
        .font(TVType.body)
        .foregroundStyle(TVPalette.textMid)
        .focusable()
    }
  }

  private func isSelected(_ source: LivePlaybackVideoSource) -> Bool {
    guard let selected = controller.selectedVideoSourceID else { return false }
    return controller.availableVideoSources.first { $0.selectionID == selected }?.effectiveHeight == source.effectiveHeight
  }

  private func choice(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
    Button {
      action()
      session.closePanel()
    } label: {
      HStack {
        Text(verbatim: label)
        Spacer()
        if selected { Image(systemName: "checkmark") }
      }
      .frame(width: 560, alignment: .leading)
    }
    .buttonStyle(.tvPill)
    .focused($choiceFocus, equals: label)
    .accessibilityAddTraits(selected ? .isSelected : [])
  }
}
