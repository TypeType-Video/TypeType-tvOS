import Foundation

extension LiveDeArrowStore {
  static let batchWidth = 8
  static let batchBudget: Duration = .seconds(2)

  // Android TV's DeArrowBranding.apply: the community titles and thumbnails of a whole screen, eight requests at a
  // time, waited for two seconds at most. Answers that come later stay in the store for the next load.
  func branded(_ videos: [LiveVideoItem]) async -> [LiveVideoItem] {
    var seen = Set<String>()
    let unique = videos.filter { seen.insert($0.canonicalID).inserted }
    let work = Task { await self.prepareAll(unique) }
    await withTaskGroup(of: Void.self) { group in
      group.addTask { await work.value }
      group.addTask { _ = try? await Task.sleep(for: Self.batchBudget) }
      await group.next()
      group.cancelAll()
    }
    return videos.map { $0.branded(branding(for: $0)) }
  }

  private func prepareAll(_ videos: [LiveVideoItem]) async {
    await withTaskGroup(of: Void.self) { group in
      for (index, video) in videos.enumerated() {
        if index >= Self.batchWidth { await group.next() }
        group.addTask { await self.prepare(video) }
      }
    }
  }
}

extension LiveVideoItem {
  func branded(_ branding: LiveVideoBranding) -> LiveVideoItem {
    let thumbnail = branding.thumbnailURL?.absoluteString ?? thumbnailURL
    guard branding.title != title || thumbnail != thumbnailURL else { return self }
    return LiveVideoItem(
      id: id, title: branding.title, url: url, thumbnailURL: thumbnail, uploaderName: uploaderName,
      uploaderURL: uploaderURL, uploaderAvatarURL: uploaderAvatarURL, duration: duration, viewCount: viewCount,
      uploadDate: uploadDate, uploaded: uploaded, streamType: streamType, isShortFormContent: isShortFormContent,
      uploaderVerified: uploaderVerified, shortDescription: shortDescription, publishedAt: publishedAt, isLive: isLive,
      isPostLive: isPostLive, isLiveContent: isLiveContent, requiresMembership: requiresMembership
    )
  }
}
