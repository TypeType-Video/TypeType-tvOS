import SwiftUI
import UIKit

struct TVHeldArrows: UIViewRepresentable {
  let enabled: Bool
  let onStep: (Int) -> Void

  func makeUIView(context: Context) -> TVHeldArrowsView { TVHeldArrowsView() }

  func updateUIView(_ view: TVHeldArrowsView, context: Context) {
    view.enabled = enabled
    view.onStep = onStep
  }

  static func dismantleUIView(_ view: TVHeldArrowsView, coordinator: ()) { view.detach() }
}

final class TVHeldArrowsView: UIView {
  var enabled = false {
    didSet { if !enabled { stop() } }
  }
  var onStep: (Int) -> Void = { _ in }
  private weak var host: UIView?
  private var repeating: Task<Void, Never>?
  private lazy var recognizers = [(UIPress.PressType.leftArrow, -1), (.rightArrow, 1)].map { type, direction in
    let held = TVRemoteHold(target: self, action: direction < 0 ? #selector(heldLeft) : #selector(heldRight))
    held.allowedPressTypes = [NSNumber(value: type.rawValue)]
    held.allowedTouchTypes = []
    held.minimumPressDuration = 0.35
    held.cancelsTouchesInView = false
    return held
  }

  private static let interval: Duration = .milliseconds(50)

  override func didMoveToWindow() {
    super.didMoveToWindow()
    guard window != nil else { return detach() }
    var responder = next
    while let current = responder, !(current is UIViewController) { responder = current.next }
    guard let root = (responder as? UIViewController)?.view, root !== host else { return }
    detach()
    host = root
    recognizers.forEach(root.addGestureRecognizer)
  }

  func detach() {
    stop()
    recognizers.forEach { host?.removeGestureRecognizer($0) }
    host = nil
  }

  @objc private func heldLeft(_ held: UILongPressGestureRecognizer) { follow(held, direction: -1) }

  @objc private func heldRight(_ held: UILongPressGestureRecognizer) { follow(held, direction: 1) }

  private func follow(_ held: UILongPressGestureRecognizer, direction: Int) {
    TVJournal.note("player", "hold \(direction < 0 ? "left" : "right") state \(held.state.rawValue) enabled \(enabled)")
    switch held.state {
    case .began where enabled:
      stop()
      repeating = Task { [weak self] in
        repeat { self?.onStep(direction) } while (try? await Task.sleep(for: Self.interval)) != nil
      }
    case .began, .changed: break
    default: stop()
    }
  }

  private func stop() {
    repeating?.cancel()
    repeating = nil
  }
}
