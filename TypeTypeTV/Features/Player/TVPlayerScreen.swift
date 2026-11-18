import SwiftUI

struct TVPlayerScreen: View {
  let video: LiveVideoItem
  @ObservedObject var playback: LivePlaybackCoordinator
  let dependencies: AppDependencies
  var onOpenChannel: (String) -> Void = { _ in }
  var onOpenPlaylist: (LivePlaylistResult) -> Void = { _ in }
  let onClose: () -> Void

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()
      if let controller = playback.controller {
        TVPlayerContent(
          controller: controller, playback: playback, dependencies: dependencies, onClose: close,
          onOpenChannel: { url in
            close()
            onOpenChannel(url)
          },
          onOpenPlaylist: { playlist in
            close()
            onOpenPlaylist(playlist)
          }
        )
        .id(ObjectIdentifier(controller))
      }
    }
    .onAppear { playback.open(video) }
  }

  private func close() {
    playback.controller?.flushHistory()
    playback.close()
    onClose()
  }
}
