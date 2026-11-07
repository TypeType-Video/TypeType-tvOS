import SwiftUI

struct TVRemoteImage: View {
  let url: URL?
  var size: LiveImageSize = .card
  var placeholder = true
  @State private var loaded: (url: URL?, image: UIImage)?
  @Environment(\.displayScale) private var displayScale
  @Environment(\.imagePipeline) private var pipeline

  var body: some View {
    GeometryReader { proxy in
      let pixels = max(proxy.size.width, proxy.size.height) * displayScale
      ZStack {
        if placeholder { TVPalette.surfaceRaised }
        if let image = shownImage(pixels) {
          Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
            .transition(.opacity)
        }
      }
      .task(id: LoadKey(url: url, pixels: pixels)) { await load(pixels) }
    }
    .accessibilityHidden(true)
  }

  private struct LoadKey: Hashable {
    let url: URL?
    let pixels: CGFloat
  }

  private func shownImage(_ pixels: CGFloat) -> UIImage? {
    if let loaded, loaded.url == url { return loaded.image }
    guard let resolved = LiveImageURLResolver.resolve(url, size: size), pixels > 0 else { return nil }
    return pipeline.cachedImage(for: resolved, maxPixelSize: pixels)
  }

  private func load(_ pixels: CGFloat) async {
    let requested = url
    guard pixels > 0, let resolved = LiveImageURLResolver.resolve(requested, size: size) else { return }
    if pipeline.cachedImage(for: resolved, maxPixelSize: pixels) != nil { return }
    guard let image = await pipeline.image(for: resolved, maxPixelSize: pixels),
      !Task.isCancelled, requested == url
    else { return }
    withAnimation(.easeOut(duration: 0.2)) { loaded = (requested, image) }
  }
}
