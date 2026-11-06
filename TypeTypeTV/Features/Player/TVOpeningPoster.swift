import SwiftUI

struct TVOpeningPoster: View {
  let video: LiveVideoItem

  var body: some View {
    ZStack(alignment: .bottomLeading) {
      TVRemoteImage(url: video.thumbnail, size: .poster).opacity(0.5)
      LinearGradient(colors: [.clear, TVPalette.ink], startPoint: .center, endPoint: .bottom)
      VStack(alignment: .leading, spacing: 20) {
        ProgressView()
        Text(verbatim: video.title).font(TVType.headline).foregroundStyle(TVPalette.textHigh).lineLimit(2)
      }
      .padding(TVDimens.safeStart)
    }
    .ignoresSafeArea()
    .allowsHitTesting(false)
  }
}
