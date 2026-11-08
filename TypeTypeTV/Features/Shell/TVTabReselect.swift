import SwiftUI
import UIKit

struct TVTabReselect: UIViewRepresentable {
  let menuReturns: Bool
  let onReselect: () -> Void
  let onMenu: () -> Void

  func makeUIView(context: Context) -> TVTabReselectView { TVTabReselectView() }

  func updateUIView(_ view: TVTabReselectView, context: Context) {
    view.onReselect = onReselect
    view.onMenu = onMenu
    view.menuReturns = menuReturns
  }
}

final class TVTabReselectView: UIView {
  var onReselect: () -> Void = {}
  var onMenu: () -> Void = {}
  var menuReturns = false {
    didSet { menu.isEnabled = menuReturns }
  }
  private weak var tabs: UITabBarController?
  private weak var watched: UIWindow?
  private let press = TVPressStartWatch(.select)
  private lazy var menu = recognizer(.menu, #selector(returnToContent), passesOn: false)

  override func didMoveToWindow() {
    super.didMoveToWindow()
    if let window, window !== watched {
      watched?.removeGestureRecognizer(press)
      watched = window
      press.onStart = { [weak self] in self?.selectStarted() }
      window.addGestureRecognizer(press)
    }
    attach()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    if tabs == nil { attach() }
  }

  private func recognizer(_ type: UIPress.PressType, _ action: Selector, passesOn: Bool) -> TVRemoteTap {
    let recognizer = TVRemoteTap(target: self, action: action)
    recognizer.allowedPressTypes = [NSNumber(value: type.rawValue)]
    recognizer.allowedTouchTypes = []
    recognizer.cancelsTouchesInView = !passesOn
    return recognizer
  }

  private func attach() {
    let found = window?.rootViewController.flatMap(Self.tabBarController(in:))
    guard found !== tabs else { return }
    tabs?.tabBar.removeGestureRecognizer(menu)
    tabs = found
    TVJournal.note("tabs", "tab bar found: \(found != nil)")
    found?.tabBar.addGestureRecognizer(menu)
    menu.isEnabled = menuReturns
  }

  private func selectStarted() {
    guard let bar = tabs?.tabBar, Self.holdsFocus(bar) else { return }
    TVJournal.note("tabs", "select started on the tab bar")
    onReselect()
  }

  private static func holdsFocus(_ view: UIView) -> Bool {
    view.isFocused || view.subviews.contains(where: holdsFocus)
  }

  @objc private func returnToContent() {
    TVJournal.note("tabs", "menu on tab bar recognized")
    onMenu()
  }

  private static func tabBarController(in controller: UIViewController) -> UITabBarController? {
    if let tabs = controller as? UITabBarController { return tabs }
    let next = controller.children + [controller.presentedViewController].compactMap { $0 }
    for child in next {
      if let tabs = tabBarController(in: child) { return tabs }
    }
    return nil
  }
}

private struct TVContentFocusKey: EnvironmentKey {
  static let defaultValue = 0
}

extension EnvironmentValues {
  var tvContentFocusRequest: Int {
    get { self[TVContentFocusKey.self] }
    set { self[TVContentFocusKey.self] = newValue }
  }
}
