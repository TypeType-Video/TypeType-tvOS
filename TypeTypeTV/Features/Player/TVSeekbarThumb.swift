import SwiftUI
import UIKit

struct TVSeekbarThumb: View {
  let icon: LiveSeekbarIcon
  let emphasized: Bool

  static func size(for icon: LiveSeekbarIcon, emphasized: Bool) -> CGFloat {
    switch icon {
    case .plain: 40
    case .typeType, .custom: emphasized ? 72 : 52
    }
  }

  var body: some View {
    Group {
      switch icon {
      case .plain: Circle().fill(TVPalette.textHigh)
      case .typeType: TVSeekbarGlyph()
      case let .custom(url): TVSeekbarRemoteIcon(url: url)
      }
    }
    .frame(width: Self.size(for: icon, emphasized: emphasized), height: Self.size(for: icon, emphasized: emphasized))
    .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}

struct TVSeekbarGlyph: View {
  private static let red = Color(red: 0xEF / 255, green: 0x44 / 255, blue: 0x44 / 255)

  var body: some View {
    Canvas { context, size in
      let scale = min(size.width, size.height) / 64
      context.translateBy(x: (size.width - 64 * scale) / 2, y: (size.height - 64 * scale) / 2)
      context.scaleBy(x: scale, y: scale)
      var antenna = Path()
      antenna.move(to: CGPoint(x: 21, y: 6))
      antenna.addLine(to: CGPoint(x: 32, y: 17))
      antenna.addLine(to: CGPoint(x: 43, y: 6))
      context.stroke(antenna, with: .color(Self.red), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
      context.fill(Path(roundedRect: CGRect(x: 5, y: 17, width: 54, height: 41), cornerRadius: 9), with: .color(Self.red))
      context.fill(Path(roundedRect: CGRect(x: 11, y: 23, width: 30, height: 29), cornerRadius: 4), with: .color(.white))
      context.fill(Path(ellipseIn: CGRect(x: 46.5, y: 27.5, width: 7, height: 7)), with: .color(.white))
      context.fill(Path(ellipseIn: CGRect(x: 46.5, y: 39.5, width: 7, height: 7)), with: .color(.white))
    }
  }
}

struct TVSeekbarRemoteIcon: View {
  let url: URL
  @State private var loaded: (url: URL, image: UIImage?)?

  var body: some View {
    Group {
      if let loaded, loaded.url == url, let image = loaded.image {
        TVAnimatedImage(image: image)
      } else {
        TVSeekbarGlyph().opacity(loaded?.url == url ? 1 : 0)
      }
    }
    .task(id: url) {
      let image = await LiveAnimatedImageLoader.seekbarIcons.image(for: url)
      guard !Task.isCancelled else { return }
      loaded = (url, image)
    }
  }
}

struct TVAnimatedImage: UIViewRepresentable {
  let image: UIImage

  func makeUIView(context: Context) -> UIImageView {
    let view = UIImageView()
    view.contentMode = .scaleAspectFit
    view.setContentHuggingPriority(.defaultLow, for: .horizontal)
    view.setContentHuggingPriority(.defaultLow, for: .vertical)
    view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
    return view
  }

  func updateUIView(_ view: UIImageView, context: Context) {
    if view.image !== image { view.image = image }
  }
}
