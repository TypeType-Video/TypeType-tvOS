import SwiftUI
import UIKit

struct TVControlTrace: UIViewRepresentable {
  func makeUIView(context: Context) -> TVControlTraceView { TVControlTraceView() }

  func updateUIView(_ view: TVControlTraceView, context: Context) {}
}

final class TVControlTraceView: UIView {
  private weak var traced: UIWindow?
  private let presses = TVPressTrace()
  private var focusObserver: NSObjectProtocol?

  override func didMoveToWindow() {
    super.didMoveToWindow()
    guard let window, window !== traced else { return }
    traced?.removeGestureRecognizer(presses)
    traced = window
    window.addGestureRecognizer(presses)
    focusObserver = focusObserver ?? NotificationCenter.default.addObserver(
      forName: UIFocusSystem.didUpdateNotification, object: nil, queue: .main
    ) { note in
      guard let context = note.userInfo?[UIFocusSystem.focusUpdateContextUserInfoKey] as? UIFocusUpdateContext else { return }
      MainActor.assumeIsolated {
        TVFocusDescription.moved(to: context.nextFocusedItem, heading: context.focusHeading)
      }
    }
  }

  deinit {
    if let focusObserver { NotificationCenter.default.removeObserver(focusObserver) }
  }
}

final class TVPressTrace: UIGestureRecognizer {
  init() {
    super.init(target: nil, action: nil)
    cancelsTouchesInView = false
    delaysTouchesEnded = false
    allowedTouchTypes = [NSNumber(value: UITouch.TouchType.indirect.rawValue)]
    allowedPressTypes = Self.types.map { NSNumber(value: $0.rawValue) }
  }

  override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool { false }

  override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool { false }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
    super.touchesBegan(touches, with: event)
    touchStart = touches.first.map { ($0.location(in: nil), $0.timestamp) }
    touching = true
    TVGestureMap.shared.traceAround(view?.window)
    TVJournal.note("touch", "finger down on \(TVFocusDescription.current)")
  }

  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
    super.touchesEnded(touches, with: event)
    traceTouchEnd(touches, "up")
  }

  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
    super.touchesCancelled(touches, with: event)
    traceTouchEnd(touches, "cancelled")
  }

  override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent) {
    super.pressesBegan(presses, with: event)
    TVGestureMap.shared.traceAround(view?.window)
    pressStart = event.timestamp
    pressesDown += presses.count
    trace(presses, "down")
  }

  override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent) {
    super.pressesEnded(presses, with: event)
    trace(presses, "up after \(Int((event.timestamp - pressStart) * 1000))ms")
    release(presses)
  }

  override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent) {
    super.pressesCancelled(presses, with: event)
    trace(presses, "cancelled")
    release(presses)
  }

  private var pressStart: TimeInterval = 0
  private var touchStart: (CGPoint, TimeInterval)?

  private func traceTouchEnd(_ touches: Set<UITouch>, _ phase: String) {
    if let touch = touches.first, let (origin, began) = touchStart {
      let point = touch.location(in: nil)
      let held = Int((touch.timestamp - began) * 1000)
      TVJournal.note("touch", "finger \(phase) after \(held)ms moved \(Int(point.x - origin.x)),\(Int(point.y - origin.y))")
    }
    touchStart = nil
    touching = false
    resetWhenIdle()
  }

  private var pressesDown = 0
  private var touching = false

  private func release(_ presses: Set<UIPress>) {
    pressesDown = max(pressesDown - presses.count, 0)
    resetWhenIdle()
  }

  private func resetWhenIdle() {
    if pressesDown == 0 && !touching { state = .failed }
  }

  private func trace(_ presses: Set<UIPress>, _ phase: String) {
    let focused = TVFocusDescription.current
    for press in presses {
      TVJournal.note("press", "\(Self.name(press.type)) \(phase) on \(focused)")
    }
  }

  private static let types: [UIPress.PressType] = [
    .upArrow, .downArrow, .leftArrow, .rightArrow, .select, .menu, .playPause, .pageUp, .pageDown,
  ]

  private static func name(_ type: UIPress.PressType) -> String {
    switch type {
    case .upArrow: "up"
    case .downArrow: "down"
    case .leftArrow: "left"
    case .rightArrow: "right"
    case .select: "select"
    case .menu: "menu"
    case .playPause: "play-pause"
    case .pageUp: "page-up"
    case .pageDown: "page-down"
    default: "press-\(type.rawValue)"
    }
  }
}
