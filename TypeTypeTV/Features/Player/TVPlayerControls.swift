import SwiftUI

enum TVPlayerFocus: Hashable {
  case catcher
  case seek
  case play
  case captions
  case danmaku
  case chat
  case audio
  case quality
  case info
  case channel
  case more
}

struct TVPlayerControls: View {
  @ObservedObject var controller: LivePlayerController
  @ObservedObject var session: TVPlayerSession
  var focus: FocusState<TVPlayerFocus?>.Binding
  let onNext: (() -> Void)?
  var chatAvailable = false

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
        TVJournal.note("player", "move \(direction) on seek bar")
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
      TVRepeatingCircleButton(systemImage: "gobackward.10", label: "Back 10 seconds") { session.seek(by: -10) }
      TVCircleButton(systemImage: controller.state == .playing ? "pause.fill" : "play.fill",
                     label: controller.state == .playing ? "Pause" : "Play", emphasized: true, action: session.togglePlay)
        .focused(focus, equals: .play)
      TVRepeatingCircleButton(systemImage: "goforward.10", label: "Forward 10 seconds") { session.seek(by: 10) }
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
          controller.cycleCaptions()
          session.touch()
        } label: {
          Label(on ? track.displayLanguageName : String(localized: "Captions"),
                systemImage: on ? "captions.bubble.fill" : "captions.bubble")
        }
        .buttonStyle(on ? .tvPillEmphasized : .tvPill)
        .focused(focus, equals: .captions)
        .accessibilityLabel(on ? Text("Captions on, \(track.displayLanguageName). Press for the next language.")
                               : Text("Captions off. Press to turn them on."))
      }
      if controller.supportsBulletComments {
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
      if chatAvailable {
        let on = session.chatShown
        Button {
          session.chatShown.toggle()
          session.touch()
        } label: { Label("Chat", systemImage: on ? "bubble.left.and.bubble.right.fill" : "bubble.left.and.bubble.right") }
          .buttonStyle(on ? .tvPillEmphasized : .tvPill)
          .focused(focus, equals: .chat)
          .accessibilityLabel(on ? Text("Live chat is shown. Press to hide it.")
                                 : Text("Live chat is hidden. Press to show it."))
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
      if !controller.video.uploaderURL.isEmpty {
        TVChannelAvatarButton(video: controller.video) { session.open(.channel) }
          .focused(focus, equals: .channel)
      }
      TVCircleButton(systemImage: "info.circle", label: "Description") { session.open(.info) }
        .focused(focus, equals: .info)
      TVCircleButton(systemImage: "ellipsis", label: "More options") { session.open(.menu) }
        .focused(focus, equals: .more)
    }
    .focusSection()
  }
}
