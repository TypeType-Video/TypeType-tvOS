import UIKit

final class TVRemoteTap: UITapGestureRecognizer {
  override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool { false }
}

final class TVRemoteHold: UILongPressGestureRecognizer {
  override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool { false }
}

final class TVPressStartWatch: UIGestureRecognizer {
  var onStart: () -> Void = {}

  init(_ type: UIPress.PressType) {
    super.init(target: nil, action: nil)
    allowedPressTypes = [NSNumber(value: type.rawValue)]
    allowedTouchTypes = []
    cancelsTouchesInView = false
  }

  override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool { false }

  override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool { false }

  override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent) {
    super.pressesBegan(presses, with: event)
    onStart()
  }

  override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent) {
    super.pressesEnded(presses, with: event)
    state = .failed
  }

  override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent) {
    super.pressesCancelled(presses, with: event)
    state = .failed
  }
}
