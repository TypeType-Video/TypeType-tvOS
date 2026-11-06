import SwiftUI

// Opens the options of a video from anywhere in the app; the shell shows the panel over every tab.
private struct TVVideoMenuKey: EnvironmentKey {
  static let defaultValue: ((LiveVideoItem) -> Void)? = nil
}

private struct TVVideoMenuShownKey: EnvironmentKey {
  static let defaultValue = false
}

extension EnvironmentValues {
  var tvVideoMenu: ((LiveVideoItem) -> Void)? {
    get { self[TVVideoMenuKey.self] }
    set { self[TVVideoMenuKey.self] = newValue }
  }

  var tvVideoMenuShown: Bool {
    get { self[TVVideoMenuShownKey.self] }
    set { self[TVVideoMenuShownKey.self] = newValue }
  }
}

// A long press on a video opens its options. The release of that press follows right after and must not open the
// video too; the view that opened the menu takes the focus back once it closes, as on Android TV.
struct TVVideoMenuTarget: ViewModifier {
  let video: LiveVideoItem
  @Binding var openedAt: Date?
  let refocus: () -> Void
  @Environment(\.tvVideoMenu) private var openMenu
  @Environment(\.tvVideoMenuShown) private var menuShown

  func body(content: Content) -> some View {
    content
      .simultaneousGesture(LongPressGesture(minimumDuration: 0.6).onEnded { _ in
        guard let openMenu else { return }
        openedAt = Date()
        openMenu(video)
      })
      .onChange(of: menuShown) { _, shown in
        guard !shown, openedAt != nil else { return }
        openedAt = nil
        Task { refocus() }
      }
  }

  static func swallowsRelease(_ openedAt: Date?) -> Bool {
    guard let openedAt else { return false }
    return Date().timeIntervalSince(openedAt) < 0.8
  }
}

extension View {
  func tvVideoMenu(_ video: LiveVideoItem, openedAt: Binding<Date?>, refocus: @escaping () -> Void) -> some View {
    modifier(TVVideoMenuTarget(video: video, openedAt: openedAt, refocus: refocus))
  }
}

// Android TV's VideoMenuPanel: a long press on a card opens the same actions as the video page, without leaving
// the row. The focus stays in the panel until Back closes it.
struct TVVideoMenuPanel: View {
  @StateObject private var actions: LiveVideoQuickActionsViewModel
  @State private var pickingPlaylist = false
  @FocusState private var focus: String?
  let video: LiveVideoItem
  let onPlay: () -> Void
  let onOpenChannel: () -> Void
  let onClose: () -> Void

  init(
    video: LiveVideoItem, dependencies: AppDependencies, onPlay: @escaping () -> Void,
    onOpenChannel: @escaping () -> Void, onClose: @escaping () -> Void
  ) {
    _actions = StateObject(wrappedValue: LiveVideoQuickActionsViewModel(video: video, dependencies: dependencies))
    self.video = video
    self.onPlay = onPlay
    self.onOpenChannel = onOpenChannel
    self.onClose = onClose
  }

  var body: some View {
    ZStack(alignment: .trailing) {
      TVPalette.ink.opacity(0.8).ignoresSafeArea()
      VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 28) {
          TVRemoteImage(url: video.thumbnail).frame(width: 256, height: 144)
            .clipShape(RoundedRectangle(cornerRadius: TVDimens.cardRadius))
          VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: video.title).font(TVType.title).foregroundStyle(TVPalette.textHigh).lineLimit(2)
            Text(verbatim: video.uploaderName).font(TVType.meta).foregroundStyle(TVPalette.textMid).lineLimit(1)
          }
        }
        .accessibilityElement(children: .combine)
        .padding(.bottom, 16)
        row("play", "Play", "play.fill", perform: onPlay)
        if !video.uploaderURL.isEmpty { row("channel", "Open channel", "person.crop.circle", perform: onOpenChannel) }
        row("playlists", "Add to a playlist", "text.badge.plus") { pickingPlaylist = true }
          .disabled(!actions.isPrepared)
        row("later", actions.isInWatchLater ? "Remove from Watch later" : "Add to Watch later",
            actions.isInWatchLater ? "bookmark.fill" : "bookmark") { Task { await actions.toggleWatchLater() } }
          .disabled(!actions.isPrepared || actions.isBusy)
        row("favorite", actions.isFavorite ? "Remove from Favorites" : "Add to Favorites",
            actions.isFavorite ? "heart.fill" : "heart") { Task { await actions.toggleFavorite() } }
          .disabled(!actions.isPrepared || actions.isBusy)
        row("block-video", "Block this video", "nosign") {
          Task {
            await actions.blockVideo()
            onClose()
          }
        }
        .padding(.top, 12)
        if !video.uploaderURL.isEmpty {
          row("block-channel", "Block this channel", "person.crop.circle.badge.xmark") {
            Task {
              await actions.blockChannel()
              onClose()
            }
          }
        }
        Spacer(minLength: 0)
      }
      .padding(.leading, 56).padding(.trailing, TVDimens.safeStart).padding(.top, 90).padding(.bottom, 60)
      .frame(width: 880)
      .frame(maxHeight: .infinity, alignment: .top)
      .background(TVPalette.surface)
      .focusSection()
      .disabled(pickingPlaylist)
      if pickingPlaylist {
        TVPlaylistPicker(actions: actions) {
          pickingPlaylist = false
          Task { focus = "playlists" }
        }
      }
    }
    .ignoresSafeArea()
    .onExitCommand { if !pickingPlaylist { onClose() } }
    .task {
      focus = "play"
      await actions.prepare()
    }
  }

  private func row(
    _ key: String, _ title: LocalizedStringKey, _ systemImage: String, perform: @escaping () -> Void
  ) -> some View {
    Button(action: perform) {
      Label(title, systemImage: systemImage).frame(maxWidth: .infinity, alignment: .leading)
    }
    .buttonStyle(.tvPill)
    .focused($focus, equals: key)
  }
}
