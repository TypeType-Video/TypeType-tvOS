import Foundation

extension LivePlaybackHTTPServer {
  func providerMasterPlaylist() throws -> String {
    guard let providerPlayback = preparation.providerPlayback,
      case let .separateHLS(videoURL, audioURL, alternates) = providerPlayback
    else {
      throw LivePlaybackFailure.invalidPlaylist
    }
    let videoRoute = register(
      target: .upstream(videoURL),
      pathExtension: "m3u8"
    )
    let audioRoute = register(
      target: .upstream(audioURL),
      pathExtension: "m3u8"
    )
    guard
      let localVideoURL = localURL(
        routeID: videoRoute,
        extension: "m3u8"
      ),
      let localAudioURL = localURL(
        routeID: audioRoute,
        extension: "m3u8"
      )
    else {
      throw LivePlaybackFailure.localPlaybackUnavailable
    }

    var lines = [
      "#EXTM3U",
      "#EXT-X-VERSION:7",
      "#EXT-X-INDEPENDENT-SEGMENTS",
      providerAudioDeclaration(url: localAudioURL),
    ]
    lines.append(contentsOf: providerSubtitleDeclarations())

    let hasSubtitles = !preparation.subtitles.isEmpty
    lines.append(
      LiveProviderHLSVariants.streamInfo(
        bandwidth: providerBandwidth,
        resolution: providerResolution,
        codecs: providerCodecs,
        hasSubtitles: hasSubtitles
      )
    )
    lines.append(localVideoURL.absoluteString)
    // The chosen quality comes first, so the player starts with it; the others let it drop when the
    // connection is slow.
    for alternate in alternates {
      let route = register(
        target: .upstream(alternate.url),
        pathExtension: "m3u8"
      )
      guard let localAlternateURL = localURL(
        routeID: route,
        extension: "m3u8"
      ) else {
        throw LivePlaybackFailure.localPlaybackUnavailable
      }
      lines.append(
        LiveProviderHLSVariants.streamInfo(
          bandwidth: alternate.bandwidth,
          resolution: alternate.resolution,
          codecs: "",
          hasSubtitles: hasSubtitles
        )
      )
      lines.append(localAlternateURL.absoluteString)
    }
    lines.append("")
    return lines.joined(separator: "\n")
  }

  private func providerAudioDeclaration(url: URL) -> String {
    let name = preparation.audio?.displayName ?? "Default"
    return
      "#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID=\"provider-audio\","
      + "NAME=\"\(hlsQuoted(name))\",DEFAULT=YES,AUTOSELECT=YES,"
      + "URI=\"\(url.absoluteString)\""
  }

  private func providerSubtitleDeclarations() -> [String] {
    let defaultIndex = preferredSubtitleIndex
    return preparation.subtitles.indices.compactMap { index in
      let routeID = register(
        target: .subtitlePlaylist(index),
        pathExtension: "m3u8"
      )
      guard let url = localURL(
        routeID: routeID,
        extension: "m3u8"
      ) else {
        return nil
      }
      let subtitle = preparation.subtitles[index]
      return
        "#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID=\"subs\","
        + "NAME=\"\(hlsQuoted(subtitle.displayName))\","
        + "LANGUAGE=\"\(hlsQuoted(subtitle.languageTag))\","
        + "AUTOSELECT=YES,DEFAULT=\(index == defaultIndex ? "YES" : "NO"),"
        + "FORCED=NO,URI=\"\(url.absoluteString)\""
    }
  }

  // Estimated the same way for the chosen quality and for the alternates, so the player ranks them right.
  private var providerBandwidth: Int {
    LiveProviderHLSVariants.bandwidth(
      videoBitrate: preparation.video?.bitrate,
      height: preparation.video?.effectiveHeight ?? 0,
      audioBitrate: preparation.audio?.bitrate
    )
  }

  private var providerCodecs: String {
    [
      preparation.video?.codec,
      preparation.audio?.codec,
    ]
    .compactMap { value in
      guard let value, !value.isEmpty else { return nil }
      return value
    }
    .joined(separator: ",")
  }

  private var providerResolution: String? {
    guard let video = preparation.video else { return nil }
    return LiveProviderHLSVariants.resolution(
      width: video.width,
      height: video.effectiveHeight
    )
  }
}
