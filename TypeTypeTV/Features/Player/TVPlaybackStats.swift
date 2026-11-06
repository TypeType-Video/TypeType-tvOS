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
    .padding(.trailing, TVDimens.safeStart).padding(.top, 80)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    .allowsHitTesting(false)
    .task {
      while !Task.isCancelled {
        buffer = await controller.nativePlayback?.player.bufferedAhead() ?? 0
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
    guard let source = controller.preparation?.video, source.width > 0, source.height > 0 else { return "-" }
    return [
      "\(source.width)x\(source.height)\(source.fps > 0 ? " \(source.fps) fps" : "")",
      source.codec ?? "",
      source.bitrate.map(Self.bitrate) ?? "",
    ].filter { !$0.isEmpty }.joined(separator: "  ")
  }

  private var audio: String {
    guard let source = controller.preparation?.audio else { return "-" }
    let parts = [source.codec ?? "", source.bitrate.map(Self.bitrate) ?? ""].filter { !$0.isEmpty }
    return parts.isEmpty ? "-" : parts.joined(separator: "  ")
  }

  private static func bitrate(_ bits: Int) -> String {
    bits >= 1_000_000 ? String(format: "%.1f Mbps", Double(bits) / 1_000_000) : "\(Int((Double(bits) / 1_000).rounded())) kbps"
  }
}
