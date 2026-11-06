import AVFoundation
import SwiftUI

// Android TV's PlaybackStatsOverlay with what the in-house player knows: the chosen video and audio formats, the
// buffer ahead and the speed, refreshed twice a second. Dropped frames, decoder and network are not measured here.
struct TVPlaybackStats: View {
  @ObservedObject var controller: LivePlayerController
  @State private var buffer: TimeInterval = 0

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      line("Video", video)
      line("Audio", audio)
      line("Buffer", String(format: "%.1f s", buffer))
      line("Speed", "\(controller.playbackRate.formatted())x")
    }
    .font(.system(size: 26, weight: .medium, design: .monospaced))
    .foregroundStyle(TVPalette.textHigh)
    .padding(.horizontal, 32).padding(.vertical, 24)
    .background(TVPalette.ink.opacity(0.8), in: RoundedRectangle(cornerRadius: TVDimens.panelRadius))
    .task {
      while !Task.isCancelled {
        if let native = controller.nativePlayback {
          buffer = await native.player.bufferedAhead()
        } else {
          buffer = Self.bufferedAhead(controller.player)
        }
        guard (try? await Task.sleep(for: .milliseconds(500))) != nil else { return }
      }
    }
  }

  private func line(_ name: LocalizedStringKey, _ value: String) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 20) {
      Text(name).frame(width: 140, alignment: .leading)
      Text(verbatim: value)
    }
  }

  private var video: String {
    guard let source = controller.preparation?.video, source.effectiveHeight > 0 else { return "-" }
    let size = source.width > 0 ? "\(source.width)x\(source.effectiveHeight)" : "\(source.effectiveHeight)p"
    return [
      "\(size)\(source.fps > 0 ? " \(source.fps) fps" : "")",
      source.codec ?? "",
      source.bitrate.flatMap(Self.bitrate) ?? "",
    ].filter { !$0.isEmpty }.joined(separator: "  ")
  }

  private var audio: String {
    guard let source = controller.preparation?.audio else { return "-" }
    let parts = [source.codec ?? "", source.bitrate.flatMap(Self.bitrate) ?? ""].filter { !$0.isEmpty }
    return parts.isEmpty ? "-" : parts.joined(separator: "  ")
  }

  // Some providers report kilobits, others bits; no figure rather than a wrong one when none is reported.
  private static func bitrate(_ reported: Int) -> String? {
    guard let bits = LiveProviderHLSVariants.bits(reported) else { return nil }
    return bits >= 1_000_000 ? String(format: "%.1f Mbps", Double(bits) / 1_000_000) : "\(Int((Double(bits) / 1_000).rounded())) kbps"
  }

  // AVPlayer plays lives, NicoNico and offline videos: its loaded range around the playhead is the buffer.
  private static func bufferedAhead(_ player: AVPlayer) -> TimeInterval {
    let now = player.currentTime()
    guard let range = player.currentItem?.loadedTimeRanges.map(\.timeRangeValue).first(where: { $0.containsTime(now) })
    else { return 0 }
    return max(range.end.seconds - now.seconds, 0)
  }
}

// Android TV's SponsorLabelBadge: the kind of the marked part being watched, while it plays.
struct TVSponsorLabel: View {
  @ObservedObject var controller: LivePlayerController

  var body: some View {
    TimelineView(.periodic(from: .now, by: 0.5)) { _ in
      if let window = controller.activeSponsorBlockWindow(at: controller.precisePosition) {
        HStack(spacing: 16) {
          Circle().fill(TVPalette.accent).frame(width: 18, height: 18)
          Text(verbatim: LiveSponsorBlockPolicy.title(for: window.segment.category)).font(TVType.title).lineLimit(1)
        }
        .foregroundStyle(TVPalette.textHigh)
        .padding(.horizontal, 28).padding(.vertical, 14)
        .background(TVPalette.glassStrong, in: Capsule())
        .transition(.opacity)
        .accessibilityElement(children: .combine)
      }
    }
  }
}
