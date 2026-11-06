import AVFoundation
import SwiftUI

struct LiveNativeVideoView: UIViewRepresentable {
  typealias Surface = LiveNativeVideoSurface

  let playback: LiveNativePlayback
  let controller: LivePlayerController
  var surface = Surface.page
  var onSwipeAdjustment: ((PlayerSwipeAdjustmentEvent) -> Void)? = nil
  var onHorizontalSeek: ((PlayerHorizontalSeekEvent) -> Void)? = nil
  var onFullscreenExit: (() -> Void)? = nil

  func makeCoordinator() -> LivePlayerLayerCoordinator {
    LivePlayerLayerCoordinator(controller: controller)
  }

  func makeUIView(context: Context) -> LiveNativeVideoHostView {
    let view = LiveNativeVideoHostView()
    view.surface = surface
    view.backgroundColor = .black
    // Never paint outside the host: interim frames bleed a band under the controls during the transition.
    view.clipsToBounds = true
    if onSwipeAdjustment != nil || onHorizontalSeek != nil || onFullscreenExit != nil {
      context.coordinator.surfaceGestures.install(in: view)
    }
    updateUIView(view, context: context)
    return view
  }

  func updateUIView(_ view: LiveNativeVideoHostView, context: Context) {
    playback.player.videoLayer.videoGravity = controller.imageMode.videoGravity
    if view.window != nil && view.bounds.size.width > 0 {
      view.setNeedsLayout()
    }
    view.surface = surface
    if view.owner !== playback.layerOwner {
      view.owner = playback.layerOwner
      if view.window != nil { playback.layerOwner.attach(view) }
    }
    // Do not re-bind while landscape full screen owns the layer: a controller on a layer that changes windows gets
    // promoted to PiP.
    if surface == .page, !controller.isPresentingFullscreen {
      controller.pictureInPicture.installNativeContent(
        layer: playback.player.videoLayer,
        playback: playback.pictureInPictureSource
      )
    }
    context.coordinator.surfaceGestures.swipeHandler = onSwipeAdjustment
    context.coordinator.surfaceGestures.horizontalSeekHandler = onHorizontalSeek
    context.coordinator.surfaceGestures.fullscreenExitHandler = onFullscreenExit
  }

  static func dismantleUIView(_ view: LiveNativeVideoHostView, coordinator: LivePlayerLayerCoordinator) {
    coordinator.invalidate()
  }
}
