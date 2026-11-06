import SwiftUI

struct TVPlayerMenuRows: View {
  @ObservedObject var controller: LivePlayerController
  @ObservedObject var session: TVPlayerSession
  @ObservedObject var actions: LiveVideoQuickActionsViewModel
  @ObservedObject var engagement: LiveVideoEngagementViewModel
  @FocusState private var focused: String?

  var body: some View {
    Group {
      if !controller.availableChapters.isEmpty {
        row("chapters", "Chapters", "list.bullet") { session.open(.chapters) }
      }
      row("description", "Description", "info.circle") { session.open(.info) }
      row("comments", "Comments", "text.bubble") { session.open(.comments) }
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
