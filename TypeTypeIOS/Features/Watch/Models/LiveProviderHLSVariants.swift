import Foundation

// One quality of a provider whose video comes as one HLS playlist per quality (NicoNico).
struct LiveProviderHLSVariant: Equatable {
  let url: URL
  let bandwidth: Int
  let resolution: String?
  var codecs = ""
}

// The master playlist lists every quality, so the player starts with the best one and drops to a lighter one
// when the connection cannot keep up, as the web client does with hls.js.
enum LiveProviderHLSVariants {
  static let audioGroup = "provider-audio"

  // The qualities listed next to the chosen one: never a better one than it, the best of them first.
  static func alternates(
    among candidates: [LivePlaybackVideoSource],
    selected: LivePlaybackVideoSource,
    heightCap: Int?
  ) -> [LivePlaybackVideoSource] {
    let limit = selected.effectiveHeight > 0 ? selected.effectiveHeight : heightCap
    var seen: Set<String> = [selected.url]
    let kept = candidates.filter { source in
      guard source.isHLSDelivery, !source.isSABR, !source.url.isEmpty else { return false }
      if let limit, source.effectiveHeight > limit { return false }
      return seen.insert(source.url).inserted
    }
    return kept.enumerated().sorted { lhs, rhs in
      if lhs.element.effectiveHeight != rhs.element.effectiveHeight {
        return lhs.element.effectiveHeight > rhs.element.effectiveHeight
      }
      let lhsBitrate = lhs.element.bitrate ?? 0
      let rhsBitrate = rhs.element.bitrate ?? 0
      if lhsBitrate != rhsBitrate { return lhsBitrate > rhsBitrate }
      return lhs.offset < rhs.offset
    }.map(\.element)
  }

  // The server reports kilobits for some providers and bits for others.
  static func bits(_ bitrate: Int?) -> Int? {
    guard let bitrate, bitrate > 0 else { return nil }
    return bitrate < 10_000 ? bitrate * 1_000 : bitrate
  }

  // A quality without a reported bitrate gets the web client's estimate for its height.
  static func bandwidth(videoBitrate: Int?, height: Int, audioBitrate: Int?) -> Int {
    let video = bits(videoBitrate) ?? estimatedVideoBandwidth(height: height)
    let audio = bits(audioBitrate) ?? 128_000
    return max(video + audio, 256_000)
  }

  static func estimatedVideoBandwidth(height: Int) -> Int {
    switch height {
    case 1_080...: return 5_000_000
    case 720...: return 2_500_000
    case 480...: return 1_200_000
    case 360...: return 800_000
    default: return 500_000
    }
  }

  // Listed the same way for every variant: Apple wants CODECS on all of them or on none.
  static func codecs(video: String?, audio: String?) -> String {
    [video, audio].compactMap { $0?.isEmpty == false ? $0 : nil }.joined(separator: ",")
  }

  static func resolution(width: Int, height: Int) -> String? {
    guard height > 0, width > 0 else { return nil }
    return "\(width)x\(height)"
  }

  static func streamInfo(
    bandwidth: Int,
    resolution: String?,
    codecs: String,
    hasSubtitles: Bool
  ) -> String {
    var attributes = [
      "BANDWIDTH=\(bandwidth)",
      "AUDIO=\"\(audioGroup)\"",
    ]
    if !codecs.isEmpty {
      attributes.append("CODECS=\"\(codecs)\"")
    }
    if let resolution {
      attributes.append("RESOLUTION=\(resolution)")
    }
    if hasSubtitles {
      attributes.append("SUBTITLES=\"subs\"")
    }
    return "#EXT-X-STREAM-INF:\(attributes.joined(separator: ","))"
  }
}
