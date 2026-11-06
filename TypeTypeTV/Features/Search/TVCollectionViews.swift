import SwiftUI

struct TVVideoGrid: View {
  let videos: [LiveVideoItem]
  let isLoadingMore: Bool
  var columnCount = 4
  var cardWidth: CGFloat = 392
  let onOpen: (LiveVideoItem) -> Void
  let onNearEnd: () -> Void

  var body: some View {
    let columns = Array(repeating: GridItem(.fixed(cardWidth), spacing: 40, alignment: .top), count: columnCount)
    LazyVGrid(columns: columns, alignment: .leading, spacing: 56) {
      ForEach(Array(videos.enumerated()), id: \.element.canonicalID) { index, video in
        TVVideoCard(video: video, width: cardWidth, onOpen: { onOpen(video) })
          .onAppear { if index >= videos.count - columnCount * 2 { onNearEnd() } }
      }
    }
    .padding(.horizontal, TVDimens.safeStart)
    .focusSection()
    if isLoadingMore { ProgressView().frame(maxWidth: .infinity) }
  }
}
