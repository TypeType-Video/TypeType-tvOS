import Foundation

// Android TV's BlockedSets: the account's blocked videos and channels, by address.
struct LiveBlockedSets: Equatable {
  var videos: Set<String> = []
  var channels: Set<String> = []

  func allows(_ video: LiveVideoItem) -> Bool {
    !videos.contains(video.url) && (video.uploaderURL.isEmpty || !channels.contains(video.uploaderURL))
  }

  func filter(_ list: [LiveVideoItem]) -> [LiveVideoItem] {
    videos.isEmpty && channels.isEmpty ? list : list.filter(allows)
  }
}
