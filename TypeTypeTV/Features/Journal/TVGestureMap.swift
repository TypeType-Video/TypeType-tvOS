import UIKit

@MainActor
final class TVGestureMap: NSObject {
  static let shared = TVGestureMap()
  private let traced = NSHashTable<UIGestureRecognizer>.weakObjects()
  weak var focusedItem: UIFocusItem?

  func traceAround(_ window: UIWindow?) {
    var view = Self.view(of: focusedItem) ?? window
    while let current = view {
      for recognizer in current.gestureRecognizers ?? [] where !traced.contains(recognizer) && !(recognizer is TVPressTrace) {
        traced.add(recognizer)
        recognizer.addTarget(self, action: #selector(changed(_:)))
      }
      view = current.superview
    }
  }

  @objc private func changed(_ recognizer: UIGestureRecognizer) {
    guard recognizer.state != .changed else { return }
    let owner = recognizer.view.map { String(describing: type(of: $0)) } ?? "detached"
    let presses = (recognizer.allowedPressTypes as [NSNumber]).map(\.intValue)
    TVJournal.note("gesture", "\(type(of: recognizer)) on \(owner) \(Self.state(recognizer.state)) presses \(presses)")
  }

  private static func view(of item: UIFocusItem?) -> UIView? {
    if let view = item as? UIView { return view }
    var environment = item?.parentFocusEnvironment
    while let current = environment {
      if let view = current as? UIView { return view }
      if let controller = current as? UIViewController { return controller.view }
      environment = current.parentFocusEnvironment
    }
    return nil
  }

  private static func state(_ state: UIGestureRecognizer.State) -> String {
    switch state {
    case .possible: "possible"
    case .began: "began"
    case .changed: "changed"
    case .ended: "recognized"
    case .cancelled: "cancelled"
    case .failed: "failed"
    @unknown default: "state-\(state.rawValue)"
    }
  }
}
