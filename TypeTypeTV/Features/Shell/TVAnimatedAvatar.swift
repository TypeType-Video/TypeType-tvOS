import ImageIO
import SwiftUI
import UIKit

// The account picture when it is animated (a GIF or an animated WebP or PNG). Its frames are decoded once, away
// from the main thread, at the size shown; a still picture returns nil and the caller shows it as usual.
struct TVAnimatedAvatar: UIViewRepresentable {
  let frames: TVAvatarFrames
  let playing: Bool

  func makeUIView(context: Context) -> TVAnimatingImageView {
    let view = TVAnimatingImageView()
    view.contentMode = .scaleAspectFill
    view.clipsToBounds = true
    return view
  }

  func updateUIView(_ view: TVAnimatingImageView, context: Context) {
    if view.animationImages != frames.images {
      view.animationImages = frames.images
      view.animationDuration = frames.duration
      view.image = frames.images.first
    }
    view.plays = playing
  }
}

// UIKit drops the frame animation of a view that is not in a window yet, or that moves to another one, while
// isAnimating still answers true: the animation is started again once the view is on screen.
final class TVAnimatingImageView: UIImageView {
  var plays = false {
    didSet { refresh() }
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    refresh()
  }

  private func refresh() {
    guard plays, window != nil else { return stopAnimating() }
    if layer.animationKeys()?.isEmpty ?? true {
      stopAnimating()
      startAnimating()
    }
  }
}

struct TVAvatarFrames: Equatable {
  let images: [UIImage]
  let duration: TimeInterval

  static func load(_ url: URL, pixels: CGFloat) async -> TVAvatarFrames? {
    guard let resolved = LiveImageURLResolver.resolve(url) else { return nil }
    do {
      let (data, _) = try await URLSession.shared.data(from: resolved)
      return await Task.detached(priority: .utility) { decode(data, pixels: pixels) }.value
    } catch {
      return nil
    }
  }

  private static func decode(_ data: Data, pixels: CGFloat) -> TVAvatarFrames? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetCount(source) > 1 else { return nil }
    let options = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceThumbnailMaxPixelSize: pixels,
      kCGImageSourceCreateThumbnailWithTransform: true,
    ] as CFDictionary
    var images: [UIImage] = []
    var duration: TimeInterval = 0
    for index in 0..<min(CGImageSourceGetCount(source), 300) {
      guard let frame = CGImageSourceCreateThumbnailAtIndex(source, index, options) else { continue }
      images.append(UIImage(cgImage: frame))
      duration += delay(source, index)
    }
    return images.count > 1 ? TVAvatarFrames(images: images, duration: duration) : nil
  }

  // Browsers show a frame that asks for less than 20 ms for 100 ms; doing the same keeps old GIFs at their speed.
  private static func delay(_ source: CGImageSource, _ index: Int) -> TimeInterval {
    let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any] ?? [:]
    let containers = [kCGImagePropertyGIFDictionary, kCGImagePropertyWebPDictionary, kCGImagePropertyPNGDictionary]
    let unclamped = [kCGImagePropertyGIFUnclampedDelayTime, kCGImagePropertyWebPUnclampedDelayTime, kCGImagePropertyAPNGUnclampedDelayTime]
    let clamped = [kCGImagePropertyGIFDelayTime, kCGImagePropertyWebPDelayTime, kCGImagePropertyAPNGDelayTime]
    for (container, keys) in zip(containers, zip(unclamped, clamped)) {
      guard let values = properties[container] as? [CFString: Any] else { continue }
      let value = (values[keys.0] as? Double) ?? (values[keys.1] as? Double) ?? 0
      return value < 0.02 ? 0.1 : value
    }
    return 0.1
  }
}
