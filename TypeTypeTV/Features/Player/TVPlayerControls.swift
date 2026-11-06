import SwiftUI

enum TVPlayerFocus: Hashable {
  case catcher
  case seek
  case play
  case captions
  case danmaku
  case audio
  case quality
  case info
  case more
}

struct TVPlayerControls: View {
  @ObservedObject var controller: LivePlayerController
  @ObservedObject var session: TVPlayerSession
  var focus: FocusState<TVPlayerFocus?>.Binding
  let onNext: (() -> Void)?

  var body: some View {
    ZStack {
      VStack {
        LinearGradient(colors: [TVPalette.ink.opacity(0.85), .clear], startPoint: .top, endPoint: .bottom).frame(height: 300)
        Spacer()
        LinearGradient(colors: [.clear, TVPalette.ink.opacity(0.92)], startPoint: .top, endPoint: .bottom).frame(height: 460)
      }
      .ignoresSafeArea()
      .allowsHitTesting(false)
      VStack(alignment: .leading) {
        titleBlock
        Spacer()
        timeline
        HStack {
          transportRow.fixedSize()
          Spacer(minLength: 40)
          // The chips keep their whole label: the space between the two rows gives way first.
          preferenceRow.fixedSize()
        }
        .padding(.top, 20)
      }
      .padding(.horizontal, TVDimens.safeStart)
      .padding(.vertical, 56)
    }
  }

  private var titleBlock: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 20) {
        if let service = VideoService.hosting(controller.video.url) { TVBadge(text: service.name, tone: .service) }
        if let height = controller.currentHeight, height >= 720 { TVBadge(text: height >= 2_160 ? "4K" : "HD", tone: .plain) }
        Text(verbatim: controller.video.uploaderName.uppercased())
          .font(TVType.label)
          .tracking(3.6)
          .foregroundStyle(TVPalette.textMid)
      }
      Text(verbatim: controller.video.title)
        .font(TVType.headline)
        .foregroundStyle(TVPalette.textHigh)
        .lineLimit(1)
    }
    .padding(.trailing, 320)
  }

  private var timeline: some View {
    HStack(spacing: 28) {
      Text(verbatim: TVTime.label(session.scrubSeconds ?? controller.position))
        .font(TVType.meta).monospacedDigit().foregroundStyle(TVPalette.textHigh).frame(width: 130, alignment: .leading)
      Button(action: session.togglePlay) {
        TVSeekBar(
          position: controller.position, duration: controller.duration, scrub: session.scrubSeconds,
          chapters: controller.availableChapters, sponsors: controller.visibleSponsorBlockWindows,
          storyboard: LivePlaybackPreviewFrames.best(controller.stream?.previewFrames ?? [])
        )
      }
      .buttonStyle(TVBareButtonStyle())
      .focused(focus, equals: .seek)
      .onMoveCommand { direction in
        switch direction {
        case .left: session.scrub(direction: -1)
        case .right: session.scrub(direction: 1)
        default: session.touch()
        }
      }
      Text(verbatim: session.isLive ? String(localized: "LIVE") : TVTime.label(controller.duration))
        .font(TVType.meta).monospacedDigit().foregroundStyle(session.isLive ? TVPalette.accent : TVPalette.textHigh)
        .frame(width: 130, alignment: .trailing)
    }
  }

  private var transportRow: some View {
    HStack(spacing: 24) {
      TVCircleButton(systemImage: "backward.end.fill", label: "Start over", action: session.startOver)
      TVCircleButton(systemImage: "gobackward.10", label: "Back 10 seconds") { session.seek(by: -10) }
      TVCircleButton(systemImage: controller.state == .playing ? "pause.fill" : "play.fill",
                     label: controller.state == .playing ? "Pause" : "Play", emphasized: true, action: session.togglePlay)
        .focused(focus, equals: .play)
      TVCircleButton(systemImage: "goforward.10", label: "Forward 10 seconds") { session.seek(by: 10) }
      TVCircleButton(systemImage: "forward.end.fill", label: "Next video") { onNext?() }
        .disabled(onNext == nil)
    }
    .focusSection()
  }

  private var preferenceRow: some View {
    HStack(spacing: 20) {
      if let track = controller.captionTrack {
        let on = controller.subtitlesEnabled
        Button {
          controller.setSubtitlesEnabled(!on)
          session.touch()
        } label: {
          Label(on ? track.displayLanguageName : String(localized: "Captions"),
                systemImage: on ? "captions.bubble.fill" : "captions.bubble")
        }
        .buttonStyle(on ? .tvPillEmphasized : .tvPill)
        .focused(focus, equals: .captions)
        .accessibilityLabel(on ? Text("Captions on, \(track.displayLanguageName). Press to turn them off.")
                               : Text("Captions off. Press to turn them on."))
      }
      if controller.supportsBulletComments {
        // Android TV's comments chip: the comments that fly over a NicoNico video, shown or not.
        let on = controller.bulletCommentsEnabled
        Button {
          controller.setBulletCommentsEnabled(!on)
          session.touch()
        } label: { Label("Comments", systemImage: on ? "text.bubble.fill" : "text.bubble") }
          .buttonStyle(on ? .tvPillEmphasized : .tvPill)
          .focused(focus, equals: .danmaku)
          .accessibilityLabel(on ? Text("Comments on the video are shown. Press to hide them.")
                                 : Text("Comments on the video are hidden. Press to show them."))
      }
      if controller.audioTracks.count > 1, let track = controller.currentAudioTrack {
        Button { session.open(.audio) } label: { Label(track.label, systemImage: "globe") }
          .buttonStyle(.tvPill)
          .focused(focus, equals: .audio)
          .accessibilityLabel(Text("Audio language, \(track.label)"))
      }
      if !controller.availableVideoSources.isEmpty {
        Button { session.open(.quality) } label: {
          Label(controller.qualityLabel, systemImage: "4k.tv")
        }
        .buttonStyle(.tvPill)
        .focused(focus, equals: .quality)
      }
      TVCircleButton(systemImage: "info.circle", label: "Description") { session.open(.info) }
        .focused(focus, equals: .info)
      TVCircleButton(systemImage: "ellipsis", label: "More options") { session.open(.menu) }
        .focused(focus, equals: .more)
    }
    .focusSection()
  }
}
