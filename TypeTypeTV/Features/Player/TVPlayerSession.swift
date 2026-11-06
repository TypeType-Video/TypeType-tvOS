import Combine
import Foundation

@MainActor
final class TVPlayerSession: ObservableObject {
  enum Panel: Hashable {
    case menu
    case chapters
    case quality
    case audio
    case speed
    case playlists
    case queue
    case comments
    case info
  }

  @Published var controlsVisible = true
  @Published private(set) var controlsFromBelow = false
  @Published var relatedOpen = false
  @Published var upNextDismissed = false
  @Published var panel: Panel?
  // The options row last chosen, so coming back from a section lands on it instead of at the top.
  var menuEntry: String?
  private var panelFromMenu = false
  @Published private(set) var scrub = LiveScrubState()

  private weak var controller: LivePlayerController?
  private var resumeAfterScrub = false
  private var commitTask: Task<Void, Never>?
  private var hideTask: Task<Void, Never>?

  private static let controlsTimeout: Duration = .milliseconds(4_500)
  private static let scrubCommit: Duration = .milliseconds(800)

  init(controller: LivePlayerController) {
    self.controller = controller
  }

  var scrubSeconds: TimeInterval? {
    scrub.target.map { TimeInterval($0) / 1_000 }
  }

  func showControls(fromBelow: Bool = false) {
    controlsFromBelow = fromBelow
    controlsVisible = true
    touch()
  }

  // Every remote press restarts the timer: the controls hide 4.5 s after the last one while the video plays.
  func touch() {
    hideTask?.cancel()
    hideTask = Task { [weak self] in
      guard (try? await Task.sleep(for: Self.controlsTimeout)) != nil, let self else { return }
      guard self.controller?.state == .playing, self.panel == nil, !self.relatedOpen, !self.scrub.isActive else { return }
      self.controlsVisible = false
    }
  }

  func togglePlay() {
    guard let controller else { return }
    // At the end, Play starts the video over; resuming there would end it at once and restart the Up next countdown.
    if controller.state != .playing, controller.duration > 0, controller.position >= controller.duration - 1 {
      controller.replay()
    } else {
      controller.togglePlayback()
    }
    showControls()
  }

  func seek(by seconds: TimeInterval) {
    guard let controller else { return }
    controller.seek(to: controller.position + seconds)
    touch()
  }

  func startOver() {
    controller?.seek(to: 0)
    touch()
  }

  // The picture holds still while the target moves, and plays again from the chosen point after a short pause.
  // Left after an automatic skip goes back to the start of the skipped part; it is not skipped again.
  func undoSkip() -> Bool {
    guard let controller, let notice = controller.sponsorBlockNotice, !notice.muted else { return false }
    controller.sponsorBlockNotice = nil
    controller.seek(to: notice.start)
    return true
  }

  func scrub(direction: Int) {
    guard let controller, !isLive else { return }
    if !scrub.isActive {
      resumeAfterScrub = controller.state == .playing
      if resumeAfterScrub { controller.togglePlayback() }
    }
    scrub.move(
      current: Int64(controller.position * 1_000),
      direction: direction,
      duration: Int64(controller.duration * 1_000)
    )
    controlsFromBelow = false
    controlsVisible = true
    touch()
    commitTask?.cancel()
    commitTask = Task { [weak self] in
      guard (try? await Task.sleep(for: Self.scrubCommit)) != nil else { return }
      self?.commitScrub()
    }
  }

  // Playback resumes before the seek: the controller keeps a playing video playing across a seek, while a resume after
  // it would find the player still loading and leave the video paused.
  func commitScrub() {
    commitTask?.cancel()
    let target = scrub.commit()
    resumeScrubbedPlayback()
    guard let target else { return }
    controller?.seek(to: TimeInterval(target) / 1_000)
    traceSeek(to: TimeInterval(target) / 1_000)
  }

  // Same line as the Android TV app writes, so both apps can be compared from their logs.
  private func traceSeek(to target: TimeInterval) {
    let started = ContinuousClock.now
    Task { [weak self] in
      for _ in 0..<400 {
        guard (try? await Task.sleep(for: .milliseconds(50))) != nil, let controller = self?.controller else { return }
        if controller.state == .playing, controller.position > target + 0.2 {
          let elapsed = ContinuousClock.now - started
          let milliseconds = elapsed.components.seconds * 1_000 + elapsed.components.attoseconds / 1_000_000_000_000_000
          AppLogger.playback.notice("seek ready after \(milliseconds) ms")
          return
        }
      }
    }
  }

  // Back closes the innermost layer first; false means the player itself should close.
  func back() -> Bool {
    if scrub.isActive {
      commitTask?.cancel()
      scrub.cancel()
      resumeScrubbedPlayback()
    } else if panel != nil {
      if panelFromMenu, panel != .menu {
        panelFromMenu = false
        panel = .menu
        return true
      }
      closePanel()
    } else if relatedOpen {
      relatedOpen = false
      showControls(fromBelow: true)
    } else if controlsVisible {
      controlsVisible = false
    } else {
      return false
    }
    return true
  }

  func open(_ target: Panel) {
    hideTask?.cancel()
    panelFromMenu = panel == .menu
    if target == .menu, panel == nil { menuEntry = nil }
    panel = target
  }

  func closePanel() {
    panelFromMenu = false
    menuEntry = nil
    panel = nil
    showControls()
  }

  var isLive: Bool {
    controller?.stream?.isLive ?? controller?.video.isLive ?? false
  }

  private func resumeScrubbedPlayback() {
    if resumeAfterScrub, controller?.state == .paused { controller?.togglePlayback() }
    resumeAfterScrub = false
    touch()
  }
}
