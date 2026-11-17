import Foundation

extension LiveVideoMetadataContentView {
  func rewindTwitchLive(_ archive: LiveTwitchArchive, to position: TimeInterval) {
    Task { [playerController, playbackCoordinator] in
      playbackCoordinator.open(await playerController.prepareTwitchRewind(archive, to: position))
    }
  }
}
