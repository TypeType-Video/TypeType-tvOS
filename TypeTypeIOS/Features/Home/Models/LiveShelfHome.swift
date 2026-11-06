import Foundation

struct LiveHomeShelf: Identifiable, Equatable {
  let id: String
  let title: String
  let videos: [LiveVideoItem]
  var progress: [String: Double] = [:]
}

struct LiveShelfHome: Equatable {
  let featured: [LiveVideoItem]
  let shelves: [LiveHomeShelf]
}
