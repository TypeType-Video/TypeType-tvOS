import SwiftUI
import UIKit

// tvOS selects a tab as soon as the focus lands on it, and a Select press on the open tab never reaches the
// TabView. A Select press in the tab bar means "back to this tab's first screen", like a click on Android TV's
// top navigation, so it is heard on the UIKit tab bar itself.
struct TVTabReselect: UIViewRepresentable {
  let onReselect: () -> Void

  func makeUIView(context: Context) -> TVTabReselectView { TVTabReselectView() }

  func updateUIView(_ view: TVTabReselectView, context: Context) { view.onReselect = onReselect }
}

final class TVTabReselectView: UIView {
  var onReselect: () -> Void = {}
  private weak var tabBar: UITabBar?
  private lazy var press: UITapGestureRecognizer = {
    let press = UITapGestureRecognizer(target: self, action: #selector(pressed))
    press.allowedPressTypes = [NSNumber(value: UIPress.PressType.select.rawValue)]
    press.cancelsTouchesInView = false
    return press
  }()

  override func didMoveToWindow() {
    super.didMoveToWindow()
    attach()
  }

  // The TabView may join the window after this view does.
  override func layoutSubviews() {
    super.layoutSubviews()
    if tabBar == nil { attach() }
  }

  private func attach() {
    let found = window?.rootViewController.flatMap(Self.tabBarController(in:))?.tabBar
    guard found !== tabBar else { return }
    tabBar?.removeGestureRecognizer(press)
    tabBar = found
    found?.addGestureRecognizer(press)
  }

  @objc private func pressed() { onReselect() }

  private static func tabBarController(in controller: UIViewController) -> UITabBarController? {
    if let tabs = controller as? UITabBarController { return tabs }
    let next = controller.children + [controller.presentedViewController].compactMap { $0 }
    for child in next {
      if let tabs = tabBarController(in: child) { return tabs }
    }
    return nil
  }
}
