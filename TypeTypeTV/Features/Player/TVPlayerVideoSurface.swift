import AVFoundation
import SwiftUI

struct TVPlayerVideoSurface: View {
  @ObservedObject var controller: LivePlayerController

  var body: some View {
    Group {
      if let native = controller.nativePlayback {
        TVNativeVideoView(playback: native)
      } else {
        TVAVPlayerLayerView(player: controller.player)
      }
    }
    .ignoresSafeArea()
    .accessibilityHidden(true)
  }
}

private struct TVNativeVideoView: UIViewRepresentable {
  let playback: LiveNativePlayback

  func makeUIView(context: Context) -> LiveNativeVideoHostView {
    let view = LiveNativeVideoHostView()
    view.backgroundColor = .black
    view.clipsToBounds = true
    view.surface = .fullscreen
    updateUIView(view, context: context)
    return view
  }

  func updateUIView(_ view: LiveNativeVideoHostView, context: Context) {
    playback.player.videoLayer.videoGravity = .resizeAspect
    guard view.owner !== playback.layerOwner else { return }
    view.owner = playback.layerOwner
    if view.window != nil { playback.layerOwner.attach(view) }
  }
}

private struct TVAVPlayerLayerView: UIViewRepresentable {
  let player: AVPlayer

  func makeUIView(context: Context) -> PlayerLayerView {
    let view = PlayerLayerView()
    view.backgroundColor = .black
    view.playerLayer.videoGravity = .resizeAspect
    view.playerLayer.player = player
    return view
  }

  func updateUIView(_ view: PlayerLayerView, context: Context) {
    if view.playerLayer.player !== player { view.playerLayer.player = player }
  }

  final class PlayerLayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer {
      layer as? AVPlayerLayer ?? AVPlayerLayer()
    }
  }
}
