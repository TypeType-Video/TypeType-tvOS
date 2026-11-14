import SwiftUI

struct TVChannelPosts: View {
  @StateObject private var model: LiveChannelPostsViewModel
  let onOpenVideo: (String) -> Void

  init(channelURL: String, service: LiveChannelServiceProtocol, onOpenVideo: @escaping (String) -> Void) {
    _model = StateObject(wrappedValue: LiveChannelPostsViewModel(channelURL: channelURL, service: service))
    self.onOpenVideo = onOpenVideo
  }

  var body: some View {
    Group {
      switch model.state {
      case .loading:
        ProgressView().frame(maxWidth: .infinity).padding(.top, 80)
      case .empty:
        Text("This channel has not posted anything.").font(TVType.body).foregroundStyle(TVPalette.textMid)
          .padding(.horizontal, TVDimens.safeStart).padding(.vertical, 80)
      case let .failed(message):
        TVScreenFailure(message: message) { Task { await model.load() } }
      case .loaded:
        LazyVStack(alignment: .leading, spacing: 28) {
          ForEach(Array(model.posts.enumerated()), id: \.element.id) { index, post in
            TVPostCard(post: post) { post.video.map { onOpenVideo($0.url) } }
              .onAppear { if index >= model.posts.count - 2 { Task { await model.loadMore() } } }
          }
        }
        .padding(.horizontal, TVDimens.safeStart)
        .focusSection()
      }
    }
    .task { await model.load() }
  }
}

private struct TVPostCard: View {
  let post: LiveCommunityPost
  let onSelect: () -> Void

  var body: some View {
    Button(action: onSelect) {
      VStack(alignment: .leading, spacing: 14) {
        HStack(spacing: 14) {
          TVRemoteImage(url: LiveImageURLResolver.resolve(post.authorAvatarURL)).frame(width: 48, height: 48).clipShape(Circle())
          Text(verbatim: post.authorName).font(TVType.title)
          Text(verbatim: post.publishedDisplay).font(TVType.meta).foregroundStyle(TVPalette.textMid)
        }
        if !post.displayText.isEmpty {
          Text(verbatim: post.displayText).font(TVType.body).lineLimit(8)
        }
        if let url = post.images.first.flatMap({ LiveImageURLResolver.resolve($0) }) {
          TVRemoteImage(url: url).frame(width: 640, height: 360).clipShape(RoundedRectangle(cornerRadius: 16))
        }
        if let poll = post.poll {
          VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(poll.choices.enumerated()), id: \.offset) { _, choice in
              Text(verbatim: choice).font(TVType.body).padding(.horizontal, 20).padding(.vertical, 10)
                .frame(maxWidth: 800, alignment: .leading)
                .background(TVPalette.surfaceRaised, in: RoundedRectangle(cornerRadius: 12))
            }
            if !poll.textualVoteCount.isEmpty {
              Text(verbatim: poll.textualVoteCount).font(TVType.meta).foregroundStyle(TVPalette.textMid)
            }
          }
        }
        if let video = post.video {
          Label { Text(verbatim: video.title).lineLimit(2) } icon: { Image(systemName: "play.rectangle.fill") }
            .font(TVType.title).foregroundStyle(TVPalette.accentSoft)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .buttonStyle(TVPostCardStyle())
  }
}

private struct TVPostCardStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    TVPostCardLabel(configuration: configuration)
  }
}

private struct TVPostCardLabel: View {
  let configuration: ButtonStyleConfiguration
  @Environment(\.isFocused) private var isFocused

  var body: some View {
    configuration.label
      .foregroundStyle(TVPalette.textHigh)
      .padding(28)
      .background(isFocused ? TVPalette.surfaceRaised : TVPalette.surface)
      .clipShape(RoundedRectangle(cornerRadius: TVDimens.panelRadius))
      .scaleEffect(isFocused ? 1.01 : 1)
      .animation(.easeOut(duration: 0.14), value: isFocused)
  }
}
