import SwiftUI

// Android TV's SeekPreview: the storyboard picture of the scrub point, the chapter there and the time.
struct TVSeekPreview: View {
  static let width: CGFloat = 480
  let position: TimeInterval
  let chapter: String?
  let storyboard: LivePlaybackPreviewFrames?

  var body: some View {
    VStack(spacing: 10) {
      if let frame = storyboard?.frame(at: position) { picture(frame) }
      if let chapter { Text(verbatim: chapter).font(TVType.meta).foregroundStyle(TVPalette.textHigh).lineLimit(1) }
      Text(verbatim: TVTime.label(position))
        .font(TVType.meta).monospacedDigit()
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 10))
    }
    .frame(width: Self.width)
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }

  private func picture(_ frame: LivePlaybackStoryboardFrame) -> some View {
    TVStoryboardFrame(frame: frame)
      .frame(width: Self.width, height: Self.width * CGFloat(frame.frameHeight) / CGFloat(max(frame.frameWidth, 1)))
      .background(TVPalette.surfaceRaised)
      .clipShape(RoundedRectangle(cornerRadius: TVDimens.cardRadius))
      .overlay(RoundedRectangle(cornerRadius: TVDimens.cardRadius).stroke(TVPalette.textHigh, lineWidth: 4))
  }
}

// Cuts the frame out of the storyboard sheet itself: an offset sheet inside a clipped frame still drew whole.
private struct TVStoryboardFrame: View {
  let frame: LivePlaybackStoryboardFrame
  @State private var sheet: (url: URL, image: UIImage)?
  @Environment(\.imagePipeline) private var pipeline

  var body: some View {
    ZStack {
      if let picture = cropped() { Image(uiImage: picture).resizable().interpolation(.medium) }
    }
    .task(id: frame.url) {
      let url = frame.url
      let size = CGFloat(max(frame.frameWidth * frame.columns, frame.frameHeight * frame.rows))
      guard sheet?.url != url, let resolved = LiveImageURLResolver.resolve(url),
        let image = await pipeline.image(for: resolved, maxPixelSize: size), !Task.isCancelled
      else { return }
      sheet = (url, image)
    }
  }

  private func cropped() -> UIImage? {
    guard let sheet, sheet.url == frame.url, let cgImage = sheet.image.cgImage, frame.columns > 0, frame.rows > 0 else {
      return nil
    }
    let width = CGFloat(cgImage.width) / CGFloat(frame.columns)
    let height = CGFloat(cgImage.height) / CGFloat(frame.rows)
    let rect = CGRect(x: CGFloat(frame.column) * width, y: CGFloat(frame.row) * height, width: width, height: height)
    return cgImage.cropping(to: rect.integral).map { UIImage(cgImage: $0) }
  }
}
