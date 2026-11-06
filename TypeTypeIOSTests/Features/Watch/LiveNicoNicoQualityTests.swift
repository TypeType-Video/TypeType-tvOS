import XCTest
@testable import TypeTypeIOS

// NicoNico reports height 0, width 0, no bitrate and no codec for every quality, so the label ("720p") is all
// the app has to choose with. These are the sources of a real video.
final class LiveNicoNicoQualityTests: XCTestCase {
  // https://www.nicovideo.jp/watch/sm47010857 as watch.typetype.video returned it.
  private static let sm47010857 = #"""
  {"videoOnlyStreams":[{"url":"/media/m1_7jM0nWeNdPXk_7yezymB6Rjh","mimeType":"video/mp4","format":"MPEG-4","resolution":"720p","bitrate":null,"codec":null,"isVideoOnly":true,"itag":-1,"width":0,"height":0,"fps":0,"contentLength":0,"initStart":0,"initEnd":0,"indexStart":0,"indexEnd":0,"deliveryMethod":"hls","manifestUrl":null,"sabrSessionUrl":null},{"url":"/media/m1_s7ZsWiUFPRBiYEYFQprGXbMT","mimeType":"video/mp4","format":"MPEG-4","resolution":"480p","bitrate":null,"codec":null,"isVideoOnly":true,"itag":-1,"width":0,"height":0,"fps":0,"contentLength":0,"initStart":0,"initEnd":0,"indexStart":0,"indexEnd":0,"deliveryMethod":"hls","manifestUrl":null,"sabrSessionUrl":null},{"url":"/media/m1_w6g8Z4GrDqhWYbg7xOLmU7J6","mimeType":"video/mp4","format":"MPEG-4","resolution":"360p","bitrate":null,"codec":null,"isVideoOnly":true,"itag":-1,"width":0,"height":0,"fps":0,"contentLength":0,"initStart":0,"initEnd":0,"indexStart":0,"indexEnd":0,"deliveryMethod":"hls","manifestUrl":null,"sabrSessionUrl":null},{"url":"/media/m1_MGAC9aoY9gtnHhKa7IkoOZny","mimeType":"video/mp4","format":"MPEG-4","resolution":"144p","bitrate":null,"codec":null,"isVideoOnly":true,"itag":-1,"width":0,"height":0,"fps":0,"contentLength":0,"initStart":0,"initEnd":0,"indexStart":0,"indexEnd":0,"deliveryMethod":"hls","manifestUrl":null,"sabrSessionUrl":null}],"audioStreams":[{"url":"/media/m1_pjt9MoEunY6-2FYlnXuwgvGg","mimeType":"audio/mp4","format":"m4a","bitrate":192,"codec":null,"quality":"192","itag":-1,"contentLength":0,"initStart":0,"initEnd":0,"indexStart":0,"indexEnd":0,"audioTrackId":null,"audioTrackName":null,"audioLocale":null,"isOriginal":false,"deliveryMethod":"progressive","manifestUrl":null,"sabrSessionUrl":null}]}
  """#

  private struct Sources: Decodable {
    let videoOnlyStreams: [LivePlaybackVideoSource]
    let audioStreams: [LivePlaybackAudioSource]
  }

  private func sources() throws -> Sources {
    try JSONDecoder().decode(Sources.self, from: Data(Self.sm47010857.utf8))
  }

  private func service() -> LivePlaybackService {
    LivePlaybackService(
      apiClient: QualityAPIClientStub(),
      serverURLProvider: { URL(string: "https://watch.example/api") }
    )
  }

  private func preferences(quality: String, videoSourceID: String? = nil) -> LivePlaybackPreferences {
    LivePlaybackPreferences(
      quality: quality,
      videoSourceID: videoSourceID,
      audioOnly: false
    )
  }

  func testTheBestQualityIsChosenNotTheLastOneListed() throws {
    let videos = try sources().videoOnlyStreams
    XCTAssertEqual(videos.map(\.resolution), ["720p", "480p", "360p", "144p"])
    XCTAssertEqual(service().selectVideo(from: videos, quality: "1080p", requestedItag: nil)?.resolution, "720p")
    XCTAssertEqual(service().selectVideo(from: videos, quality: "auto", requestedItag: nil)?.resolution, "720p")
  }

  func testAQualityLimitPicksTheBestBelowIt() throws {
    let videos = try sources().videoOnlyStreams
    XCTAssertEqual(service().selectVideo(from: videos, quality: "480p", requestedItag: nil)?.resolution, "480p")
    XCTAssertEqual(service().selectVideo(from: videos, quality: "400p", requestedItag: nil)?.resolution, "360p")
    XCTAssertEqual(service().selectVideo(from: videos, quality: "100p", requestedItag: nil)?.resolution, "144p")
  }

  func testAutomaticQualityOffersEveryLighterQualityToTheMasterPlaylist() throws {
    let all = try sources()
    let service = service()
    let selected = try XCTUnwrap(service.selectVideo(from: all.videoOnlyStreams, quality: "1080p", requestedItag: nil))
    let alternates = service.providerHLSAlternates(
      among: all.videoOnlyStreams,
      selected: selected,
      audio: all.audioStreams[0],
      preferences: preferences(quality: "1080p")
    )
    XCTAssertEqual(
      alternates.map(\.url.path),
      all.videoOnlyStreams.dropFirst().map { "/api" + $0.url }
    )
    XCTAssertEqual(alternates.map(\.bandwidth), alternates.map(\.bandwidth).sorted(by: >))
    XCTAssertEqual(Set(alternates.map(\.bandwidth)).count, 3, "each quality needs its own bandwidth to be ranked")
    XCTAssertTrue(alternates.allSatisfy { $0.url.scheme == LivePlaybackService.authenticatedScheme })
    XCTAssertTrue(alternates.allSatisfy { $0.resolution == nil }, "no width is reported, none is invented")
  }

  func testAQualityLimitAlsoLimitsTheAlternates() throws {
    let all = try sources()
    let service = service()
    let selected = try XCTUnwrap(service.selectVideo(from: all.videoOnlyStreams, quality: "480p", requestedItag: nil))
    let alternates = service.providerHLSAlternates(
      among: all.videoOnlyStreams,
      selected: selected,
      audio: all.audioStreams[0],
      preferences: preferences(quality: "480p")
    )
    XCTAssertEqual(alternates.map(\.url.path), all.videoOnlyStreams.suffix(2).map { "/api" + $0.url })
  }

  func testAQualityPickedByHandPlaysAlone() throws {
    let all = try sources()
    let service = service()
    let picked = all.videoOnlyStreams[1]
    let alternates = service.providerHLSAlternates(
      among: all.videoOnlyStreams,
      selected: picked,
      audio: all.audioStreams[0],
      preferences: preferences(quality: "1080p", videoSourceID: picked.selectionID)
    )
    XCTAssertTrue(alternates.isEmpty)
  }

  func testEveryQualityKeepsItsOwnIdentity() throws {
    let videos = try sources().videoOnlyStreams
    XCTAssertEqual(Set(videos.map(\.selectionID)).count, 4)
    XCTAssertEqual(LivePlaybackVideoCatalog.resolutionOptions(from: videos).map(\.effectiveHeight), [144, 360, 480, 720])
  }
}

private final class QualityAPIClientStub: APIClient {
  func request<T: Decodable>(
    _ endpoint: APIEndpoint,
    as type: T.Type
  ) async throws -> T {
    throw NetworkError.invalidResponse
  }

  func request(_ endpoint: APIEndpoint) async throws {
    throw NetworkError.invalidResponse
  }

  func requestData(_ endpoint: APIEndpoint) async throws -> Data {
    throw NetworkError.invalidResponse
  }
}
