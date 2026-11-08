import UIKit

final class TVRemoteTap: UITapGestureRecognizer {
  override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool { false }
}

final class TVRemoteHold: UILongPressGestureRecognizer {
  override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool { false }
}
