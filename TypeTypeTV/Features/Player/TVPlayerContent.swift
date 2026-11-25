import SwiftUI

struct TVPlayerContent: View {
  @ObservedObject var controller: LivePlayerController
  @ObservedObject var playback: LivePlaybackCoordinator
  let onClose: () -> Void
  let onOpenChannel: (String) -> Void
  let onOpenPlaylist: (LivePlaylistResult) -> Void
  let channelService: LiveChannelServiceProtocol
  @StateObject var session: TVPlayerSession
  @StateObject var actions: LiveVideoQuickActionsViewModel
  @StateObject var engagement: LiveVideoEngagementViewModel
  @StateObject var comments: LiveCommentsViewModel
  @StateObject var threads: LiveCommentThreads
  @StateObject var voice: LiveCommentVoicePlayer
  @StateObject var chat: TVLiveChatModel
  @StateObject var twitchChat: TVTwitchChat
  let hasChatService: Bool
  @FocusState var focus: TVPlayerFocus?
  @FocusState var relatedFocus: Bool
  @State var panelOrigin: TVPlayerFocus?
  @State var chatMayConnect = false
  @State var endScreenFocused = false
  @AppStorage(TVChatLayout.key) var chatLayoutValue = TVChatLayout.over.rawValue
  @AppStorage(TVChatDensity.key) var chatDensityValue = TVChatDensity.medium.rawValue

  init(
    controller: LivePlayerController, playback: LivePlaybackCoordinator, dependencies: AppDependencies,
    onClose: @escaping () -> Void, onOpenChannel: @escaping (String) -> Void,
    onOpenPlaylist: @escaping (LivePlaylistResult) -> Void
  ) {
    self.controller = controller
    self.playback = playback
    self.onClose = onClose
    hasChatService = dependencies.liveChatService != nil
    _chat = StateObject(wrappedValue: TVLiveChatModel(videoURL: controller.video.url, service: dependencies.liveChatService))
    _twitchChat = StateObject(wrappedValue: TVTwitchChat(video: controller.video, dependencies: dependencies))
    self.onOpenChannel = onOpenChannel
    self.onOpenPlaylist = onOpenPlaylist
    channelService = dependencies.channelService
    _session = StateObject(wrappedValue: TVPlayerSession(controller: controller))
    _actions = StateObject(wrappedValue: LiveVideoQuickActionsViewModel(video: controller.video, dependencies: dependencies))
    _engagement = StateObject(wrappedValue: LiveVideoEngagementViewModel(
      video: controller.video, allowsSubscription: true, service: dependencies.subscriptionsService
    ))
    _comments = StateObject(wrappedValue: LiveCommentsViewModel(
      videoURL: controller.video.url, commentsService: dependencies.commentsService,
      settingsService: dependencies.settingsService
    ))
    _threads = StateObject(wrappedValue: LiveCommentThreads(videoURL: controller.video.url, service: dependencies.commentsService))
    _voice = StateObject(wrappedValue: LiveCommentVoicePlayer(service: dependencies.commentsService))
  }

  var body: some View {
    ZStack {
      picture
      if chatVisible, twitchChat.isAvailable {
        TVTwitchChatColumn(controller: controller, chat: twitchChat, layout: chatLayout, density: chatDensity, dimmed: chatDimmed)
          .frame(maxWidth: .infinity, alignment: .trailing)
      } else if chatVisible {
        TVLiveChatPanel(model: chat, layout: chatLayout, density: chatDensity, dimmed: chatDimmed, connects: chatMayConnect)
          .frame(maxWidth: .infinity, alignment: .trailing)
      }
      if isOpening { TVOpeningPoster(video: controller.video).padding(.trailing, chatInset) }
      catcher
      endScreen
      if session.controlsVisible, session.panel == nil {
        VStack(spacing: 0) {
          TVPlayerControls(controller: controller, session: session, focus: $focus, onNext: nextVideo.map { next in { playback.open(next) } }, chatAvailable: chatAvailable)
            .onMoveCommand { if $0 == .down, !session.relatedOpen, !related.isEmpty { session.relatedOpen = true } }
          if session.relatedOpen {
            TVShelfRow(
              shelf: LiveHomeShelf(id: "more", title: String(localized: "MORE VIDEOS"), videos: related),
              onOpen: { playback.open($0) },
              firstCardFocus: $relatedFocus
            )
            .padding(.bottom, 40)
          }
        }
        .transition(.opacity)
      }
      if !session.controlsVisible, session.panel == nil, !countdownActive { TVSponsorNotice(controller: controller) }
      if let next = upNextVideo { TVUpNextCard(next: next, fill: upNextFill, secondsLeft: upNextSecondsLeft) }
      if session.panel == .channel, controller.video.twitchLink == nil {
        TVPlayerChannelPanel(video: controller.video, service: channelService, engagement: engagement) {
          onOpenChannel(controller.video.uploaderURL)
        }
      } else if session.panel == .twitchChat, let live = twitchChat.live {
        TVTwitchChatActions(model: live)
      } else if let panel = session.panel {
        TVPlayerPanel(
          controller: controller, session: session, actions: actions, engagement: engagement,
          comments: comments, threads: threads, voice: voice, panel: panel, queue: related, onOpen: { playback.open($0) }
        )
      }
      if case let .failed(message) = controller.state {
        TVPlayerFailure(message: message, onRetry: controller.retry, onClose: onClose)
      }
    }
    .animation(.easeOut(duration: 0.2), value: session.controlsVisible)
    .animation(.easeOut(duration: 0.2), value: chatVisible)
    .background(TVHeldArrows(enabled: session.panel == nil && !session.isLive && (focus == .catcher || focus == .seek)) {
      session.scrub(direction: $0)
    })
    .task(id: controller.state == .playing) {
      guard controller.state == .playing, !chatMayConnect else { return }
      guard (try? await Task.sleep(for: .seconds(5))) != nil else { return }
      chatMayConnect = true
    }
    .onExitCommand {
      TVJournal.note("player", "back command, panel \(session.panel != nil), controls \(session.controlsVisible)")
      if endScreenFocused { return leaveEndScreen() }
      if upNextVideo != nil { return session.upNextDismissed = true }
      let hadPanel = session.panel != nil
      guard session.back() else { return onClose() }
      if !hadPanel { focus = restingFocus }
    }
    .onChange(of: session.controlsVisible) { _, _ in focus = restingFocus }
    .onChange(of: focus) { _, _ in session.touch() }
    .onChange(of: countdownActive) { _, active in
      guard active else { return }
      if session.upNextDismissed || hidesRelated { playback.cancelAutoplayCountdown() } else { playback.playUpcomingNow() }
    }
    .onChange(of: session.relatedOpen) { _, open in
      if open { Task { relatedFocus = true } }
    }
    .onChange(of: session.panel) { old, new in
      if new == .channel, controller.video.twitchLink != nil { return openTwitchChannel() }
      if old == nil, new != nil { panelOrigin = focus }
      if old != nil, new == nil { Task { focus = panelOrigin ?? .seek } }
    }
    .onAppear {
      focus = .seek
      session.touch()
    }
    .task { await prepareActions() }
    .task { await twitchChat.run() }
  }
}
