import SwiftUI

struct TVBackdrop: View {
  let artwork: URL?
  let key: String
  var preview: LivePreviewPlayback?
  var previewShowing = false
  @AppStorage(TVDeviceSetting.backdropKey) private var shown = true

  init(video: LiveVideoItem, preview: LivePreviewPlayback? = nil, previewShowing: Bool = false) {
    artwork = video.thumbnail
    key = video.canonicalID
    self.preview = preview
    self.previewShowing = previewShowing
  }

  init(artwork: URL?, key: String) {
    self.artwork = artwork
    self.key = key
  }

  var body: some View {
    ZStack {
      if let preview { TVPreviewVideoView(playback: preview) }
      if shown, !previewShowing {
        TVRemoteImage(url: artwork, size: .poster)
          .id(key)
          .transition(.opacity)
      }
      LinearGradient(
        stops: [
          .init(color: TVPalette.ink.opacity(0.96), location: 0),
          .init(color: TVPalette.ink.opacity(0.78), location: 0.42),
          .init(color: TVPalette.ink.opacity(0.18), location: 0.78),
          .init(color: .clear, location: 1),
        ],
        startPoint: .leading,
        endPoint: .trailing
      )
      LinearGradient(
        stops: [
          .init(color: TVPalette.ink.opacity(0.55), location: 0),
          .init(color: .clear, location: 0.22),
          .init(color: TVPalette.ink.opacity(0.55), location: 0.58),
          .init(color: TVPalette.ink, location: 1),
        ],
        startPoint: .top,
        endPoint: .bottom
      )
      LinearGradient(
        stops: [
          .init(color: TVPalette.ink.opacity(0.97), location: 0),
          .init(color: TVPalette.ink.opacity(0.92), location: 0.6),
          .init(color: .clear, location: 1),
        ],
        startPoint: .top,
        endPoint: .bottom
      )
      .frame(height: 230)
      .frame(maxHeight: .infinity, alignment: .top)
    }
    .animation(.easeOut(duration: 0.45), value: key)
    .animation(.easeOut(duration: 0.7), value: previewShowing)
    .ignoresSafeArea()
  }
}

private struct TVPreviewVideoView: UIViewRepresentable {
  let playback: LivePreviewPlayback

  func makeUIView(context: Context) -> LiveNativeVideoHostView {
    let view = LiveNativeVideoHostView()
    view.backgroundColor = .clear
    view.clipsToBounds = true
    updateUIView(view, context: context)
    return view
  }

  func updateUIView(_ view: LiveNativeVideoHostView, context: Context) {
    playback.player.videoLayer.videoGravity = .resizeAspectFill
    guard view.owner !== playback.layerOwner else { return }
    view.owner = playback.layerOwner
    if view.window != nil { playback.layerOwner.attach(view) }
  }
}
