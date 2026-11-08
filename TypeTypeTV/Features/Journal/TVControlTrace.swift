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

@MainActor
enum TVFocusDescription {
  static var current = "nothing"
  private static var generation = 0

  static func moved(to item: UIFocusItem?, heading: UIFocusHeading) {
    let date = Date()
    let from = current
    TVGestureMap.shared.focusedItem = item
    generation += 1
    let mine = generation
    current = of(item, labelled: false)
    let way = Self.heading(heading)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak item] in
      let to = mine == generation ? of(item, labelled: true) : current
      if mine == generation { current = to }
      TVJournal.note("focus", "\(from) -> \(to) heading \(way)", at: date)
    }
  }

  static func of(_ item: UIFocusItem?, labelled: Bool = true) -> String {
    guard let item else { return "nothing" }
    let kind = String(describing: type(of: item))
    let frame = Self.frame(of: item)
    guard labelled, let label = Self.label(of: item) else { return "\(kind) \(frame)" }
    return "\(kind) \"\(label.prefix(80))\" \(frame)"
  }

  private static func label(of item: UIFocusItem) -> String? {
    if let label = (item as? NSObject)?.accessibilityLabel, !label.isEmpty { return label }
    if let view = item as? UIView { return label(near: view, depth: 3) }
    guard let window = UIApplication.shared.connectedScenes.compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first,
      let space = item.parentFocusEnvironment?.focusItemContainer?.coordinateSpace else { return nil }
    let target = UIScreen.main.coordinateSpace.convert(item.frame, from: space)
    var best: (label: String, area: CGFloat)?
    let started = CFAbsoluteTimeGetCurrent()
    accessibleLabel(in: window, around: target, deadline: started + 0.004, best: &best)
    let spent = (CFAbsoluteTimeGetCurrent() - started) * 1000
    if spent > 3 { TVJournal.note("journal", "focus label lookup took \(Int(spent))ms") }
    return best?.label
  }

  private static func accessibleLabel(
    in node: NSObject, around target: CGRect, deadline: CFAbsoluteTime, best: inout (label: String, area: CGFloat)?
  ) {
    guard CFAbsoluteTimeGetCurrent() < deadline else { return }
    let frame = node.accessibilityFrame
    if let label = node.accessibilityLabel, !label.isEmpty, frame.contains(CGPoint(x: target.midX, y: target.midY)) {
      let area = frame.width * frame.height
      if area <= target.width * target.height * 4, area < (best?.area ?? .infinity) { best = (label, area) }
    }
    var children: [NSObject] = []
    if let elements = node.accessibilityElements as? [NSObject] {
      children = elements
    } else if node.accessibilityElementCount() > 0, node.accessibilityElementCount() != NSNotFound {
      children = (0..<node.accessibilityElementCount()).compactMap { node.accessibilityElement(at: $0) as? NSObject }
    }
    if let view = node as? UIView { children += view.subviews }
    for child in children {
      if let view = child as? UIView {
        let area = view.accessibilityFrame
        if view.isHidden || view.alpha == 0 || (!area.isEmpty && !area.contains(CGPoint(x: target.midX, y: target.midY))) { continue }
      }
      accessibleLabel(in: child, around: target, deadline: deadline, best: &best)
    }
  }

  private static func frame(of item: UIFocusItem) -> String {
    let space = (item as? UIView)?.superview?.coordinateSpace
      ?? item.parentFocusEnvironment?.focusItemContainer?.coordinateSpace
    let screen = space.map { UIScreen.main.coordinateSpace.convert(item.frame, from: $0) } ?? item.frame
    return "@\(Int(screen.minX)),\(Int(screen.minY)) \(Int(screen.width))x\(Int(screen.height))"
  }

  static func heading(_ heading: UIFocusHeading) -> String {
    let names: [(UIFocusHeading, String)] = [
      (.up, "up"), (.down, "down"), (.left, "left"), (.right, "right"), (.next, "next"), (.previous, "previous"),
    ]
    let found = names.filter { heading.contains($0.0) }.map(\.1)
    return found.isEmpty ? "none" : found.joined(separator: "+")
  }

  private static func label(near view: UIView, depth: Int) -> String? {
    if let label = view.accessibilityLabel, !label.isEmpty { return label }
    guard depth > 0 else { return nil }
    for child in view.subviews {
      if let label = label(near: child, depth: depth - 1) { return label }
    }
    return nil
  }
}
