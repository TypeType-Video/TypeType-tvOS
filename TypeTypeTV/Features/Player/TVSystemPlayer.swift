import AVKit
import SwiftUI

struct TVSystemPlayer: UIViewControllerRepresentable {
  @ObservedObject var controller: LivePlayerController

  func makeUIViewController(context: Context) -> AVPlayerViewController {
    let view = AVPlayerViewController()
    view.player = controller.player
    view.appliesPreferredDisplayCriteriaAutomatically = true
    update(view)
    return view
  }

  func updateUIViewController(_ view: AVPlayerViewController, context: Context) {
    if view.player !== controller.player { view.player = controller.player }
    update(view)
  }

  private func update(_ view: AVPlayerViewController) {
    view.transportBarCustomMenuItems = [qualityMenu()]
    guard let item = controller.player.currentItem, item.externalMetadata.isEmpty else { return }
    item.externalMetadata = metadata()
  }

  private func qualityMenu() -> UIMenu {
    let options = LivePlaybackVideoCatalog.resolutionOptions(from: controller.availableVideoSources)
    let selected = controller.selectedVideoSourceID
    let automatic = UIAction(
      title: String(localized: "Automatic"),
      state: selected == nil ? .on : .off
    ) { [controller] _ in controller.selectVideoResolution(nil) }
    let choices = options.reversed().map { source in
      UIAction(
        title: LivePlaybackVideoCatalog.qualityLabel(for: source),
        state: selected != nil && options.first { $0.selectionID == selected }?.height == source.height ? .on : .off
      ) { [controller] _ in controller.selectVideoResolution(source.height) }
    }
    return UIMenu(
      title: String(localized: "Quality"),
      image: UIImage(systemName: "slider.horizontal.3"),
      options: .singleSelection,
      children: [automatic] + choices
    )
  }

  private func metadata() -> [AVMetadataItem] {
    let video = controller.video
    var items = [Self.item(.commonIdentifierTitle, video.title), Self.item(.iTunesMetadataTrackSubTitle, video.uploaderName)]
    if let description = controller.stream?.description ?? video.shortDescription, !description.isEmpty {
      items.append(Self.item(.commonIdentifierDescription, description))
    }
    return items
  }

  private static func item(_ identifier: AVMetadataIdentifier, _ value: String) -> AVMetadataItem {
    let item = AVMutableMetadataItem()
    item.identifier = identifier
    item.value = value as NSString
    item.extendedLanguageTag = "und"
    return item
  }
}
