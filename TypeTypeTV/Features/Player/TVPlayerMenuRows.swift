import SwiftUI

struct TVPlayerMenuRows: View {
  @ObservedObject var controller: LivePlayerController
  @ObservedObject var session: TVPlayerSession
  @ObservedObject var actions: LiveVideoQuickActionsViewModel
  @ObservedObject var engagement: LiveVideoEngagementViewModel
  var queueCount = 0
  @FocusState private var focused: String?

  var body: some View {
    Group {
      if !controller.availableChapters.isEmpty {
        row("chapters", "Chapters", "list.bullet") { session.open(.chapters) }
      }
      row("description", "Description", "info.circle") { session.open(.info) }
      row("comments", "Comments", "text.bubble") { session.open(.comments) }
      if queueCount > 0 {
        row("queue", "Up next", "list.and.film", value: String(queueCount)) { session.open(.queue) }
      }
      row("favorite", actions.isFavorite ? "Favorited" : "Favorite", actions.isFavorite ? "heart.fill" : "heart") {
        Task { await actions.toggleFavorite() }
      }
      .disabled(!actions.isPrepared || actions.isBusy)
      row("watch-later", actions.isInWatchLater ? "Saved" : "Watch later",
          actions.isInWatchLater ? "bookmark.fill" : "bookmark") {
        Task { await actions.toggleWatchLater() }
      }
      .disabled(!actions.isPrepared || actions.isBusy)
      if engagement.canSubscribe {
        let name = controller.video.uploaderName
        row("subscribe", engagement.isSubscribed ? "Subscribed to \(name)" : "Subscribe to \(name)",
            engagement.isSubscribed ? "checkmark" : "bell") {
          Task { await engagement.toggleSubscription() }
        }
        .disabled(engagement.isLoading || engagement.isChanging)
      }
      row("playlists", "Add to a playlist", "text.badge.plus") { session.open(.playlists) }
        .disabled(!actions.isPrepared)
      row("speed", "Playback speed", "speedometer", value: speedLabel) { session.open(.speed) }
      row("audio-only", "Audio only", "headphones",
          value: controller.audioOnly ? String(localized: "On") : String(localized: "Off")) {
        // Android TV keeps this choice for the open video only; the next one plays with its picture again.
        controller.setAudioOnly(!controller.audioOnly, remembers: false)
      }
    }
    // Set on the next turn: set during the first layout, the focus engine keeps its own first row instead.
    .onAppear {
      let entry = session.menuEntry ?? (controller.availableChapters.isEmpty ? "description" : "chapters")
      Task { focused = entry }
    }
  }

  private var speedLabel: String {
    controller.playbackRate == 1 ? String(localized: "Normal") : "\(controller.playbackRate.formatted())×"
  }

  private func row(
    _ key: String, _ title: LocalizedStringKey, _ systemImage: String, value: String? = nil,
    action: @escaping () -> Void
  ) -> some View {
    Button {
      session.menuEntry = key
      action()
    } label: {
      HStack(spacing: 20) {
        Image(systemName: systemImage).frame(width: 40)
        Text(title)
        Spacer()
        if let value { Text(verbatim: value).opacity(0.7) }
      }
      .frame(width: 560, alignment: .leading)
    }
    .buttonStyle(.tvPill)
    .focused($focused, equals: key)
  }
}

struct TVPlayerChapterRows: View {
  @ObservedObject var controller: LivePlayerController
  @ObservedObject var session: TVPlayerSession
  @FocusState private var focused: String?

  var body: some View {
    let chapters = controller.availableChapters
    ForEach(chapters) { chapter in
      let start = TimeInterval(chapter.startTimeSeconds)
      Button {
        controller.seek(to: start)
        session.closePanel()
      } label: {
        HStack(spacing: 20) {
          Text(verbatim: TVTime.label(start)).monospacedDigit().opacity(0.7).frame(width: 110, alignment: .leading)
          Text(verbatim: chapter.title).lineLimit(2)
          Spacer()
          if chapter.id == current(in: chapters)?.id { Image(systemName: "play.fill") }
        }
        .frame(width: 560, alignment: .leading)
      }
      .buttonStyle(.tvPill)
      .focused($focused, equals: chapter.id)
      .accessibilityLabel(Text(verbatim: "\(chapter.title), \(TVTime.label(start))"))
    }
    // The list opens on the chapter being watched, as on Android TV.
    .onAppear {
      let entry = current(in: chapters)?.id ?? chapters.first?.id
      Task { focused = entry }
    }
  }

  private func current(in chapters: [LivePlaybackChapter]) -> LivePlaybackChapter? {
    chapters.last { TimeInterval($0.startTimeSeconds) <= controller.position }
  }
}

// Android TV's QueuePanel: the videos that can play next, each with its picture, channel and length.
struct TVQueueRows: View {
  let videos: [LiveVideoItem]
  let onSelect: (LiveVideoItem) -> Void
  @FocusState private var focused: String?

  var body: some View {
    ForEach(videos, id: \.canonicalID) { video in
      Button { onSelect(video) } label: {
        HStack(spacing: 20) {
          TVRemoteImage(url: video.thumbnail).frame(width: 192, height: 108).clipShape(RoundedRectangle(cornerRadius: 10))
          VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: video.title).lineLimit(2)
            Text(verbatim: [video.uploaderName, video.duration > 0 ? LiveVideoMetadataFormatter.duration(video.duration) : ""]
              .filter { !$0.isEmpty }.joined(separator: " · ")).font(TVType.meta).opacity(0.7).lineLimit(1)
          }
          Spacer(minLength: 0)
        }
        .frame(width: 560, alignment: .leading)
      }
      .buttonStyle(.tvPill)
      .focused($focused, equals: video.canonicalID)
      .accessibilityLabel(Text(verbatim: "\(video.title), \(video.uploaderName)"))
    }
    .onAppear {
      let first = videos.first?.canonicalID
      Task { focused = first }
    }
  }
}
