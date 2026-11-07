import SwiftUI

struct TVEdgeScroll: ScrollTargetBehavior {
  let rowPitch: CGFloat

  func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
    let current = context.originalTarget.rect.minY
    let proposed = target.rect.minY
    target.rect.origin.y = proposed > current
      ? min(proposed, current + rowPitch)
      : max(proposed, current - rowPitch)
  }
}
