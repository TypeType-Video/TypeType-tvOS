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
  private lazy var press = recognizer(.select, #selector(pressed), passesOn: true)
  private lazy var menu = recognizer(.menu, #selector(returnToContent), passesOn: false)

  override func didMoveToWindow() {
    super.didMoveToWindow()
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
    tabs?.tabBar.removeGestureRecognizer(press)
    tabs?.tabBar.removeGestureRecognizer(menu)
    tabs = found
    TVJournal.note("tabs", "tab bar recognizers attached: \(found != nil)")
    found?.tabBar.addGestureRecognizer(press)
    found?.tabBar.addGestureRecognizer(menu)
    menu.isEnabled = menuReturns
  }

  @objc private func pressed() {
    TVJournal.note("tabs", "select on tab bar recognized")
    onReselect()
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
