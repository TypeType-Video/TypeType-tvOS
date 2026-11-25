import SwiftUI

extension TVPlayerControls {
  var liveTimeline: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      HStack(spacing: 28) {
        TVLiveEdgeBadge(behind: controller.isBehindLiveEdge)
          .frame(width: 130, alignment: .leading)
        Button(action: session.togglePlay) {
          TVSeekBar(position: 1, duration: 1, scrub: nil, icon: LiveSeekbarIcon(settings: controller.settings))
        }
        .buttonStyle(TVBareButtonStyle())
        .focused(focus, equals: .seek)
        .onMoveCommand { direction in
          if direction == .left, archive != nil {
            session.open(.rewind)
          } else {
            session.touch()
          }
        }
        .accessibilityLabel(Text("Live"))
        .accessibilityHint(archive != nil ? Text("Press left to go back in the live.") : Text(verbatim: ""))
        Text(verbatim: elapsed(now: context.date).map(TVTime.label) ?? "")
          .font(TVType.meta).monospacedDigit().foregroundStyle(TVPalette.textHigh)
          .frame(width: 130, alignment: .trailing)
      }
    }
  }

  var liveTransportRow: some View {
    HStack(spacing: 24) {
      if archive != nil {
        TVCircleButton(systemImage: "gobackward", label: "Go back in the live") { session.open(.rewind) }
      }
      TVCircleButton(systemImage: controller.state == .playing ? "pause.fill" : "play.fill",
                     label: controller.state == .playing ? "Pause" : "Play", emphasized: true, action: session.togglePlay)
        .focused(focus, equals: .play)
      TVCircleButton(systemImage: "forward.end.fill", label: "Go live") {
        controller.goToLiveEdge()
        session.touch()
      }
      .disabled(!controller.isBehindLiveEdge)
    }
    .focusSection()
  }

  @ViewBuilder
  var liveFigures: some View {
    if let live = controller.stream?.twitchMedia?.live {
      TimelineView(.periodic(from: .now, by: 60)) { context in
        Text(verbatim: figures(live, now: context.date).joined(separator: " · "))
          .font(TVType.meta)
          .foregroundStyle(TVPalette.textMid)
          .lineLimit(1)
      }
    }
  }

  private var archive: LiveTwitchArchive? {
    controller.stream?.twitchMedia?.live?.archive
  }

  private func elapsed(now: Date) -> TimeInterval? {
    guard let started = controller.stream?.twitchMedia?.live.flatMap({ LiveTwitchFormat.date($0.startedAt) }) else { return nil }
    return max(0, now.timeIntervalSince(started))
  }

  private func figures(_ live: LiveTwitchStream, now: Date) -> [String] {
    var parts = [String(localized: "\(LiveTwitchFormat.count(live.viewers)) watching")]
    if let started = LiveTwitchFormat.date(live.startedAt) {
      let elapsed = Duration.seconds(now.timeIntervalSince(started))
      parts.append(String(localized: "Live for \(elapsed.formatted(.units(allowed: [.hours, .minutes], width: .narrow)))"))
    }
    if let game = live.game?.name { parts.append(game) }
    return parts
  }
}

struct TVLiveEdgeBadge: View {
  let behind: Bool

  var body: some View {
    HStack(spacing: 10) {
      Circle().fill(behind ? TVPalette.textMid : TVPalette.textHigh).frame(width: 12, height: 12)
      Text(behind ? "Go live" : "LIVE").font(TVType.label).tracking(2).lineLimit(1)
    }
    .foregroundStyle(TVPalette.textHigh)
    .padding(.horizontal, 14)
    .padding(.vertical, 6)
    .background(behind ? TVPalette.surfaceRaised : TVPalette.accent, in: Capsule())
    .fixedSize()
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(behind ? Text("Behind the live") : Text("Live"))
  }
}
