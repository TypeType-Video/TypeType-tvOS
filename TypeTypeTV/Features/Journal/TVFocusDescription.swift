import UIKit

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
