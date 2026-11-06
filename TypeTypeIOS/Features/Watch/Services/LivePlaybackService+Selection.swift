import Foundation

extension LivePlaybackService {
  func selectVideo(
    from sources: [LivePlaybackVideoSource],
    quality: String,
    preferredCodec: String = "recommended",
    requestedItag: Int?,
    requestedSourceID: String? = nil
  ) -> LivePlaybackVideoSource? {
    if let requestedSourceID,
      let requested = sources.first(where: {
        $0.selectionID == requestedSourceID
      }) {
      return requested
    }
    if let requestedItag,
      let requested = sources.first(where: { $0.itag == requestedItag }) {
      return requested
    }
    let target = qualityHeight(quality)
    let codecCandidates = filteredByCodec(
      sources,
      preferredCodec: preferredCodec
    )
    let codecOrdered = codecCandidates.isEmpty ? sources : codecCandidates
    let ordered = codecOrdered.sorted {
      if $0.effectiveHeight != $1.effectiveHeight { return $0.effectiveHeight < $1.effectiveHeight }
      let lhsRank = Self.codecEfficiencyRank($0.codec)
      let rhsRank = Self.codecEfficiencyRank($1.codec)
      if lhsRank != rhsRank { return lhsRank < rhsRank }
      return ($0.bitrate ?? 0) < ($1.bitrate ?? 0)
    }
    if let target {
      return ordered.last(where: { $0.effectiveHeight <= target })
        ?? ordered.first
    }
    return ordered.last
  }

  // When no quality was picked by hand, the master playlist offers the lighter qualities as well, so the
  // player can drop to one when the connection is slow.
  func providerHLSAlternates(
    among videos: [LivePlaybackVideoSource],
    selected: LivePlaybackVideoSource,
    audio: LivePlaybackAudioSource,
    preferences: LivePlaybackPreferences
  ) -> [LiveProviderHLSVariant] {
    guard preferences.videoSourceID == nil, preferences.videoItag == nil else { return [] }
    let matching = filteredByCodec(videos, preferredCodec: preferences.preferredCodec)
    return LiveProviderHLSVariants.alternates(
      among: matching.isEmpty ? videos : matching,
      selected: selected,
      heightCap: qualityHeight(preferences.quality)
    ).compactMap { source in
      guard let url = URL(string: source.url),
        let proxied = providerProxyURL(for: url, authenticated: true)
      else { return nil }
      return LiveProviderHLSVariant(
        url: proxied,
        bandwidth: LiveProviderHLSVariants.bandwidth(
          videoBitrate: source.bitrate,
          height: source.effectiveHeight,
          audioBitrate: audio.bitrate
        ),
        resolution: LiveProviderHLSVariants.resolution(
          width: source.width,
          height: source.effectiveHeight
        ),
        codecs: LiveProviderHLSVariants.codecs(video: source.codec, audio: audio.codec)
      )
    }
  }

  static func codecEfficiencyRank(_ codec: String?) -> Int {
    let codec = codec?.lowercased() ?? ""
    if codec.hasPrefix("hvc1") { return 2 }
    if codec.hasPrefix("avc1") { return 1 }
    return 0
  }

  private func filteredByCodec(
    _ sources: [LivePlaybackVideoSource],
    preferredCodec: String
  ) -> [LivePlaybackVideoSource] {
    let prefixes: [String]
    switch preferredCodec.lowercased() {
    case "av1": prefixes = ["av01"]
    case "vp9": prefixes = ["vp09", "vp9"]
    case "h264": prefixes = ["avc1"]
    default: return sources
    }
    return sources.filter { source in
      prefixes.contains {
        source.codec?.lowercased().hasPrefix($0) == true
      }
    }
  }

  func selectAudio(
    from sources: [LivePlaybackAudioSource],
    requestedTrackID: String?,
    requestedSourceID: String? = nil
  ) -> LivePlaybackAudioSource? {
    // Dictionary order changes from one launch to the next: without a fixed order the prewarm and the start can
    // pick two tracks of the same language, and the instance then builds a second session from scratch.
    let deduplicated = Dictionary(
      grouping: sources,
      by: \.id
    ).compactMap { $0.value.max(by: {
      ($0.bitrate ?? 0) < ($1.bitrate ?? 0)
    }) }
    .sorted { ($0.bitrate ?? 0, -$0.itag) > ($1.bitrate ?? 0, -$1.itag) }
    if let requestedSourceID,
      let requested = deduplicated.first(where: {
        $0.id == requestedSourceID
      }) {
      return requested
    }
    if let requestedTrackID, !requestedTrackID.isEmpty,
      let requested = deduplicated.first(where: {
        $0.audioTrackID == requestedTrackID
      }) {
      return requested
    }
    return deduplicated.first(where: \.isOriginal)
      ?? deduplicated.max(by: {
        ($0.bitrate ?? 0) < ($1.bitrate ?? 0)
      })
  }

  private func qualityHeight(_ quality: String) -> Int? {
    let digits = quality.prefix { $0.isNumber }
    return Int(digits)
  }

  func providerDeliveryMethod(
    declared: String,
    sourceURL: URL
  ) -> String {
    if sourceURL.pathExtension.caseInsensitiveCompare("m3u8")
      == .orderedSame {
      return "hls"
    }
    return declared.lowercased()
  }

  func providerProxyURL(
    for sourceURL: URL,
    authenticated: Bool
  ) -> URL? {
    // Server-hosted resources (/media/...) load directly: a relative URL wrapped in /proxy fails with "Missing URL
    // scheme".
    if sourceURL.scheme == nil || isSelectedServerURL(sourceURL) {
      guard let resolved = serverResourceURL(for: sourceURL.absoluteString) else { return nil }
      return authenticated ? authenticatedAssetURL(for: resolved) : resolved
    }
    guard let serverURL = serverURLProvider(),
      var components = URLComponents(
        url: serverURL,
        resolvingAgainstBaseURL: false
      )
    else {
      return nil
    }
    let basePath = components.path.hasSuffix("/")
      ? String(components.path.dropLast())
      : components.path
    components.path = "\(basePath)/proxy"
    components.queryItems = [
      URLQueryItem(name: "url", value: sourceURL.absoluteString),
    ]
    if authenticated {
      components.scheme = Self.authenticatedScheme
    }
    return components.url
  }
}
