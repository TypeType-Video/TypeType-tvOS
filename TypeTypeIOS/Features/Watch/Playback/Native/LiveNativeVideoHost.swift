import AVFoundation
import UIKit

enum LiveNativeVideoSurface: Int {
  case page = 1
  case mini = 2
  case fullscreen = 3
}

@MainActor
final class LiveNativeLayerOwner {
  private let layer: AVSampleBufferDisplayLayer
  private var hosts: [WeakHost] = []

  private struct WeakHost {
    weak var view: LiveNativeVideoHostView?
  }

  init(layer: AVSampleBufferDisplayLayer) {
    self.layer = layer
  }

  func attach(_ host: LiveNativeVideoHostView) {
    hosts.removeAll { $0.view == nil || $0.view === host }
    hosts.append(WeakHost(view: host))
    place()
  }

  func detach(_ host: LiveNativeVideoHostView) {
    hosts.removeAll { $0.view == nil || $0.view === host }
    place()
  }

  private func place() {
    let visible = hosts.compactMap(\.view).filter { $0.window != nil }
    guard let host = visible.max(by: { $0.surface.rawValue <= $1.surface.rawValue }) else { return }
    // No flush: it starves the picture until the next segment while audio plays on.
    host.adopt(layer)
  }
}

final class LiveNativeVideoHostView: UIView {
  weak var owner: LiveNativeLayerOwner?
  var surface = LiveNativeVideoSurface.page
  private weak var videoLayer: AVSampleBufferDisplayLayer?

  override func didMoveToWindow() {
    super.didMoveToWindow()
    if window != nil {
      owner?.attach(self)
    } else {
      owner?.detach(self)
    }
  }

  func adopt(_ layer: AVSampleBufferDisplayLayer) {
    videoLayer = layer
    guard layer.superlayer !== self.layer else { return }
    layer.removeFromSuperlayer()
    self.layer.addSublayer(layer)
    layer.frame = bounds
    setNeedsLayout()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    guard let videoLayer, videoLayer.superlayer === layer else { return }
    // No action-disabling transaction: the layer must animate with its container or a stale band shows under the
    // controls.
    videoLayer.frame = bounds
  }
}
