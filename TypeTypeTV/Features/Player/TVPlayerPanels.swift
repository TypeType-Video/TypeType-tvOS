import SwiftUI

struct TVPlayerPanel: View {
  @ObservedObject var controller: LivePlayerController
  @ObservedObject var session: TVPlayerSession
  @ObservedObject var actions: LiveVideoQuickActionsViewModel
  @ObservedObject var engagement: LiveVideoEngagementViewModel
  let comments: LiveCommentsViewModel
  let threads: LiveCommentThreads
  let panel: TVPlayerSession.Panel

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
  }

  private var title: LocalizedStringKey {
    switch panel {
    case .menu: "Player options"
    case .chapters: "Chapters"
    case .quality: "Quality"
    case .speed: "Playback speed"
    case .playlists: "Add to a playlist"
    case .comments: "Comments"
    case .info: "Description"
    }
  }

  @ViewBuilder
  private var rows: some View {
    switch panel {
    case .menu:
      TVPlayerMenuRows(controller: controller, session: session, actions: actions, engagement: engagement)
    case .chapters:
      TVPlayerChapterRows(controller: controller, session: session)
    case .comments:
      TVCommentRows(comments: comments, threads: threads)
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
    case .speed:
      ForEach(Self.speeds, id: \.self) { speed in
        choice(speed == 1 ? String(localized: "Normal") : "\(speed.formatted())×", selected: controller.playbackRate == speed) {
          controller.setPlaybackRate(speed)
        }
      }
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
    .accessibilityAddTraits(selected ? .isSelected : [])
  }
}
