import XCTest
@testable import TypeTypeIOS

final class LiveProviderHLSVariantsTests: XCTestCase {
  // The video and audio lists of https://www.nicovideo.jp/watch/sm9 as watch.typetype.video returned them: two
  // qualities that both report height 0, no bitrate and no codec, and a "progressive" audio without ranges.
  private static let sm9 = #"""
  {"videoOnlyStreams":[{"url":"/media/m1_m1Mbqloe76al62FDwmIzgteC","mimeType":"video/mp4","format":"MPEG-4","resolution":"360p","bitrate":null,"codec":null,"isVideoOnly":true,"itag":-1,"width":0,"height":0,"fps":0,"contentLength":0,"initStart":0,"initEnd":0,"indexStart":0,"indexEnd":0,"deliveryMethod":"hls","manifestUrl":null,"sabrSessionUrl":null},{"url":"/media/m1_yhPmCeEOFaH55lSoWaS1QakY","mimeType":"video/mp4","format":"MPEG-4","resolution":"360p","bitrate":null,"codec":null,"isVideoOnly":true,"itag":-1,"width":0,"height":0,"fps":0,"contentLength":0,"initStart":0,"initEnd":0,"indexStart":0,"indexEnd":0,"deliveryMethod":"hls","manifestUrl":null,"sabrSessionUrl":null}],"audioStreams":[{"url":"/media/m1_GObW6pY9g3HYMqvOW6PVgVhf","mimeType":"audio/mp4","format":"m4a","bitrate":128,"codec":null,"quality":"128","itag":-1,"contentLength":0,"initStart":0,"initEnd":0,"indexStart":0,"indexEnd":0,"audioTrackId":null,"audioTrackName":null,"audioLocale":null,"isOriginal":false,"deliveryMethod":"progressive","manifestUrl":null,"sabrSessionUrl":null}]}
  """#

  private struct Sources: Decodable {
    let videoOnlyStreams: [LivePlaybackVideoSource]
    let audioStreams: [LivePlaybackAudioSource]
  }

  private func sm9() throws -> Sources {
    try JSONDecoder().decode(Sources.self, from: Data(Self.sm9.utf8))
  }

  private func video(
    url: String,
    resolution: String,
    height: Int = 0,
    bitrate: Int? = nil,
    method: String = "hls"
  ) -> LivePlaybackVideoSource {
    LivePlaybackVideoSource(
      url: url, mimeType: "video/mp4", resolution: resolution, bitrate: bitrate, codec: nil,
      isVideoOnly: true, itag: -1, width: 0, height: height, fps: 0, contentLength: 0,
      initStart: 0, initEnd: 0, indexStart: 0, indexEnd: 0, deliveryMethod: method, manifestURL: nil
    )
  }

  func testTheQualityComesFromTheLabelWhenTheHeightIsMissing() {
    XCTAssertEqual(LivePlaybackVideoSource.height(fromResolution: "360p"), 360)
    XCTAssertEqual(LivePlaybackVideoSource.height(fromResolution: "480P 清晰"), 480)
    XCTAssertEqual(LivePlaybackVideoSource.height(fromResolution: "1080p60 HDR"), 1_080)
    XCTAssertEqual(LivePlaybackVideoSource.height(fromResolution: "Auto"), 0)
    XCTAssertEqual(LivePlaybackVideoSource.height(fromResolution: ""), 0)
    XCTAssertEqual(video(url: "/a", resolution: "720p").effectiveHeight, 720)
    XCTAssertEqual(video(url: "/a", resolution: "720p", height: 1_080).effectiveHeight, 1_080)
  }

  func testRealNicoNicoQualitiesAreTwoSourcesNotOne() throws {
    let videos = try sm9().videoOnlyStreams
    XCTAssertEqual(videos.count, 2)
    XCTAssertEqual(Set(videos.map(\.selectionID)).count, 2, "the two playlists must not share one identity")
    XCTAssertTrue(videos.allSatisfy { $0.isHLSDelivery && $0.isAppleProviderVideo })
    XCTAssertEqual(videos.map(\.effectiveHeight), [360, 360])
    XCTAssertEqual(videos.map(\.displayName), ["360p", "360p"])
  }

  func testTheQualityMenuListsNicoNicoQualities() throws {
    let options = LivePlaybackVideoCatalog.resolutionOptions(from: try sm9().videoOnlyStreams)
    XCTAssertEqual(options.map(\.effectiveHeight), [360])
  }

  func testRealNicoNicoPlaylistsBecomeOneChosenQualityAndOneAlternate() throws {
    let videos = try sm9().videoOnlyStreams
    let alternates = LiveProviderHLSVariants.alternates(among: videos, selected: videos[0], heightCap: nil)
    XCTAssertEqual(alternates.map(\.url), [videos[1].url])
  }

  func testAlternatesNeverOfferABetterQualityThanTheChosenOne() {
    let p1080 = video(url: "/1080", resolution: "1080p")
    let p720 = video(url: "/720", resolution: "720p")
    let p480 = video(url: "/480", resolution: "480p")
    let p360 = video(url: "/360", resolution: "360p")
    let sources = [p360, p1080, p480, p720]
    XCTAssertEqual(
      LiveProviderHLSVariants.alternates(among: sources, selected: p720, heightCap: 720).map(\.url),
      ["/480", "/360"]
    )
    XCTAssertEqual(
      LiveProviderHLSVariants.alternates(among: sources, selected: p1080, heightCap: nil).map(\.url),
      ["/720", "/480", "/360"]
    )
  }

  func testAlternatesSkipProgressiveAndDuplicateSources() {
    let chosen = video(url: "/720", resolution: "720p")
    let sources = [
      chosen,
      video(url: "/720", resolution: "720p"),
      video(url: "/480-progressive", resolution: "480p", method: "progressive"),
      video(url: "/480", resolution: "480p"),
    ]
    XCTAssertEqual(
      LiveProviderHLSVariants.alternates(among: sources, selected: chosen, heightCap: nil).map(\.url),
      ["/480"]
    )
  }

  func testAnUnknownHeightFallsBackToTheQualityCap() {
    let unknown = video(url: "/x", resolution: "HD")
    let sources = [unknown, video(url: "/1080", resolution: "1080p"), video(url: "/480", resolution: "480p")]
    XCTAssertEqual(
      LiveProviderHLSVariants.alternates(among: sources, selected: unknown, heightCap: 720).map(\.url),
      ["/480"]
    )
  }

  func testBandwidthUsesReportedBitratesThenTheWebEstimate() {
    XCTAssertEqual(LiveProviderHLSVariants.bandwidth(videoBitrate: nil, height: 720, audioBitrate: 192), 2_692_000)
    XCTAssertEqual(LiveProviderHLSVariants.bandwidth(videoBitrate: nil, height: 360, audioBitrate: nil), 928_000)
    XCTAssertEqual(LiveProviderHLSVariants.bandwidth(videoBitrate: 1_500_000, height: 720, audioBitrate: 128_000), 1_628_000)
    XCTAssertEqual(LiveProviderHLSVariants.bandwidth(videoBitrate: 900, height: 360, audioBitrate: 128), 1_028_000)
    XCTAssertGreaterThan(
      LiveProviderHLSVariants.bandwidth(videoBitrate: nil, height: 1_080, audioBitrate: nil),
      LiveProviderHLSVariants.bandwidth(videoBitrate: nil, height: 720, audioBitrate: nil)
    )
  }

  func testStreamInfoKeepsTheAudioGroupAndTheOptionalAttributes() {
    XCTAssertEqual(
      LiveProviderHLSVariants.streamInfo(bandwidth: 928_000, resolution: "640x360", codecs: "", hasSubtitles: false),
      "#EXT-X-STREAM-INF:BANDWIDTH=928000,AUDIO=\"provider-audio\",RESOLUTION=640x360"
    )
    XCTAssertEqual(
      LiveProviderHLSVariants.streamInfo(bandwidth: 1, resolution: nil, codecs: "avc1.64001E,mp4a.40.2", hasSubtitles: true),
      "#EXT-X-STREAM-INF:BANDWIDTH=1,AUDIO=\"provider-audio\",CODECS=\"avc1.64001E,mp4a.40.2\",SUBTITLES=\"subs\""
    )
    XCTAssertNil(LiveProviderHLSVariants.resolution(width: 0, height: 360))
    XCTAssertEqual(LiveProviderHLSVariants.resolution(width: 640, height: 360), "640x360")
  }
}
