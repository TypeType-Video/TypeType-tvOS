import SwiftUI
import UIKit

// Presses on the tvOS tab bar never reach the TabView, so they are heard on the UIKit tab bar itself.
// Select on the open tab means "back to this tab's first screen", like a click on Android TV's top navigation.
// Menu leaves the app, as everywhere on tvOS; with the "Back from the top bar" setting it returns to the tab's
// screen instead (each tab puts the focus where coming down from the bar puts it), and the app is left with the
// TV button.
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
  private lazy var press = recognizer(.select, #selector(pressed), passesOn: true)
  // Menu must not travel on: an unhandled Menu press is what leaves the app.
  private lazy var menu = recognizer(.menu, #selector(returnToContent), passesOn: false)

  override func didMoveToWindow() {
    super.didMoveToWindow()
    attach()
  }

  // The TabView may join the window after this view does.
  override func layoutSubviews() {
    super.layoutSubviews()
    if tabs == nil { attach() }
  }

  private func recognizer(_ type: UIPress.PressType, _ action: Selector, passesOn: Bool) -> UITapGestureRecognizer {
    let recognizer = UITapGestureRecognizer(target: self, action: action)
    recognizer.allowedPressTypes = [NSNumber(value: type.rawValue)]
    recognizer.cancelsTouchesInView = !passesOn
    return recognizer
  }

  private func attach() {
    let found = window?.rootViewController.flatMap(Self.tabBarController(in:))
    guard found !== tabs else { return }
    tabs?.tabBar.removeGestureRecognizer(press)
    tabs?.tabBar.removeGestureRecognizer(menu)
    tabs = found
    found?.tabBar.addGestureRecognizer(press)
    found?.tabBar.addGestureRecognizer(menu)
    menu.isEnabled = menuReturns
  }

  @objc private func pressed() { onReselect() }

  @objc private func returnToContent() { onMenu() }

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
  // Grows when Menu on the tab bar asks this tab to take the focus back.
  var tvContentFocusRequest: Int {
    get { self[TVContentFocusKey.self] }
    set { self[TVContentFocusKey.self] = newValue }
  }
}
