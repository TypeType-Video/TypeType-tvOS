import Foundation

struct LivePlaybackVideoSource: Decodable, Hashable, Identifiable {
  let url: String
  let mimeType: String
  let resolution: String
  let bitrate: Int?
  let codec: String?
  let isVideoOnly: Bool
  let itag: Int
  let width: Int
  let height: Int
  let fps: Int
  let contentLength: Int64
  let initStart: Int64
  let initEnd: Int64
  let indexStart: Int64
  let indexEnd: Int64
  let deliveryMethod: String
  let manifestURL: String?

  var id: String { selectionID }
  // NicoNico lists several qualities that share itag, codec, height and bitrate (none of them reported): the
  // address of an HLS playlist is what tells them apart, within one stream response.
  var selectionID: String {
    [
      String(itag),
      codec ?? "",
      String(height),
      String(bitrate ?? 0),
      deliveryMethod,
      isHLSDelivery ? url : "",
    ].joined(separator: ":")
  }

  var displayName: String {
    if !resolution.isEmpty { return resolution }
    if effectiveHeight > 0 { return "\(effectiveHeight)p" }
    return "Automatic"
  }

  var isAppleH264: Bool {
    mimeType.lowercased().hasPrefix("video/mp4")
      && codec?.lowercased().hasPrefix("avc1") == true
  }

  var isSABR: Bool {
    deliveryMethod.caseInsensitiveCompare("sabr") == .orderedSame
  }

  // NicoNico sends height 0 for some qualities and names them only in the label ("360p"): the label is the
  // truth there, as in the web client.
  var effectiveHeight: Int {
    height > 0 ? height : Self.height(fromResolution: resolution)
  }

  var isHLSDelivery: Bool {
    deliveryMethod.caseInsensitiveCompare("hls") == .orderedSame || isHLSPlaylist
  }

  // The number before the "p" of a label: "360p", "480P 清晰", "1080p60 HDR".
  static func height(fromResolution label: String) -> Int {
    let characters = Array(label)
    var index = 0
    while index < characters.count {
      guard characters[index].isASCII, characters[index].isNumber else {
        index += 1
        continue
      }
      var end = index
      while end < characters.count, characters[end].isASCII, characters[end].isNumber {
        end += 1
      }
      var next = end
      while next < characters.count, characters[next] == " " { next += 1 }
      if next < characters.count, characters[next] == "p" || characters[next] == "P",
        let height = Int(String(characters[index..<end])) {
        return height
      }
      index = end
    }
    return 0
  }

  var isAppleProviderVideo: Bool {
    guard mimeType.lowercased().hasPrefix("video/mp4") else {
      return false
    }
    if isHLSDelivery {
      return true
    }
    let codec = codec?.lowercased() ?? ""
    return codec.hasPrefix("avc1") || codec.hasPrefix("hvc1")
  }

  private var isHLSPlaylist: Bool {
    URL(string: url)?.pathExtension.caseInsensitiveCompare("m3u8")
      == .orderedSame
  }

  private enum CodingKeys: String, CodingKey {
    case url, mimeType, resolution, bitrate, codec, isVideoOnly
    case itag, width, height, fps, contentLength
    case initStart, initEnd, indexStart, indexEnd, deliveryMethod
    case manifestURL = "manifestUrl"
  }
}

struct LivePlaybackAudioSource: Decodable, Hashable, Identifiable {
  let url: String
  let mimeType: String
  let bitrate: Int?
  let codec: String?
  let quality: String?
  let itag: Int
  let audioTrackID: String?
  let audioTrackName: String?
  let audioLocale: String?
  let isOriginal: Bool
  let contentLength: Int64
  let initStart: Int64
  let initEnd: Int64
  let indexStart: Int64
  let indexEnd: Int64
  let deliveryMethod: String
  let manifestURL: String?

  var id: String {
    [
      String(itag),
      audioTrackID ?? "",
      audioLocale ?? "",
      String(bitrate ?? 0),
      deliveryMethod,
    ].joined(separator: ":")
  }

  var displayName: String {
    if let audioTrackName, !audioTrackName.isEmpty {
      return audioTrackName
    }
    if let audioLocale, !audioLocale.isEmpty {
      return Locale.current.localizedString(
        forIdentifier: audioLocale
      ) ?? audioLocale
    }
    return isOriginal ? "Original" : "Default"
  }

  var isAppleAAC: Bool {
    mimeType.lowercased().hasPrefix("audio/mp4")
      && codec?.lowercased().hasPrefix("mp4a") == true
  }

  var isSABR: Bool {
    deliveryMethod.caseInsensitiveCompare("sabr") == .orderedSame
  }

  var isAppleProviderAudio: Bool {
    guard mimeType.lowercased().hasPrefix("audio/mp4") else {
      return false
    }
    if deliveryMethod.caseInsensitiveCompare("hls") == .orderedSame
      || isHLSPlaylist {
      return true
    }
    // MP4 audio without a declared codec (NicoNico) is AAC in practice.
    guard let codec = codec?.lowercased() else { return true }
    return codec.hasPrefix("mp4a") || codec == "aac"
  }

  private var isHLSPlaylist: Bool {
    URL(string: url)?.pathExtension.caseInsensitiveCompare("m3u8")
      == .orderedSame
  }

  private enum CodingKeys: String, CodingKey {
    case url, mimeType, bitrate, codec, quality, itag
    case audioTrackName, audioLocale, isOriginal, contentLength
    case initStart, initEnd, indexStart, indexEnd, deliveryMethod
    case audioTrackID = "audioTrackId"
    case manifestURL = "manifestUrl"
  }
}
