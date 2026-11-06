import SwiftUI

// Android TV's ChannelPanel: the channel of the video beside the player, and whether to follow it, without leaving
// the video. The name, picture and audience show at once; the channel's first page brings the banner and the
// description.
struct TVPlayerChannelPanel: View {
  let video: LiveVideoItem
  let service: LiveChannelServiceProtocol
  @ObservedObject var engagement: LiveVideoEngagementViewModel
  let onOpenChannel: () -> Void
  @State private var page: LiveChannelPage?
  @State private var loaded = false
  @FocusState private var entry: Bool

  private static let bannerHeight: CGFloat = 380
  private static let avatarSize: CGFloat = 168

  var body: some View {
    HStack {
      Spacer()
      ZStack(alignment: .top) {
        banner
        VStack(alignment: .leading, spacing: 0) {
          avatar
          HStack(spacing: 16) {
            Text(verbatim: video.uploaderName).font(TVType.headline).foregroundStyle(TVPalette.textHigh).lineLimit(1)
            if page?.isVerified == true {
              Image(systemName: "checkmark.seal.fill").foregroundStyle(TVPalette.textMid)
                .accessibilityLabel(Text("Verified channel"))
            }
          }
          .padding(.top, 28)
          if let count = page?.subscriberCount, count > 0 {
            Text(verbatim: LiveVideoMetadataFormatter.subscribers(count)).font(TVType.meta).foregroundStyle(TVPalette.textMid)
          }
          buttons.padding(.top, 36)
          description.padding(.top, 40)
          Spacer(minLength: 0)
        }
        .padding(.horizontal, 56)
        .padding(.top, Self.bannerHeight - Self.avatarSize / 2 - 56)
      }
      .frame(width: 760)
      .frame(maxHeight: .infinity, alignment: .top)
      .background(TVPalette.surface.opacity(0.96))
      .clipped()
    }
    .ignoresSafeArea()
    .focusSection()
    .onAppear { Task { entry = true } }
    .task(id: video.uploaderURL) {
      page = try? await service.channel(url: video.uploaderURL, nextPage: nil, sort: .latest)
      loaded = true
    }
  }

  private var banner: some View {
    ZStack {
      if let url = page?.banner { TVRemoteImage(url: url) }
      LinearGradient(colors: [TVPalette.ink.opacity(0.2), TVPalette.ink.opacity(0.6), TVPalette.ink],
                     startPoint: .top, endPoint: .bottom)
    }
    .frame(width: 760, height: Self.bannerHeight)
    .clipped()
    .accessibilityHidden(true)
  }

  private var avatar: some View {
    ZStack {
      Circle().fill(TVPalette.surfaceRaised)
      Text(verbatim: String(video.uploaderName.prefix(1)).uppercased()).font(TVType.headline).foregroundStyle(TVPalette.textHigh)
      if let url = page?.avatar ?? video.uploaderAvatar { TVRemoteImage(url: url).clipShape(Circle()).padding(6) }
    }
    .frame(width: Self.avatarSize, height: Self.avatarSize)
    .overlay(Circle().stroke(TVPalette.ink, lineWidth: 6))
    .accessibilityHidden(true)
  }

  private var buttons: some View {
    HStack(spacing: 20) {
      Button(action: onOpenChannel) { Label("Open channel", systemImage: "arrow.right") }
        .buttonStyle(.tvPillEmphasized)
        .focused($entry)
      if engagement.canSubscribe {
        Button { Task { await engagement.toggleSubscription() } } label: {
          Label(engagement.isSubscribed ? "Subscribed" : "Subscribe", systemImage: engagement.isSubscribed ? "checkmark" : "bell")
        }
        .buttonStyle(.tvPill)
        .disabled(engagement.isChanging)
      }
    }
  }

  @ViewBuilder
  private var description: some View {
    if !loaded {
      // Android's DescriptionSkeleton: three lines while the channel page loads.
      VStack(alignment: .leading, spacing: 20) {
        ForEach([1, 0.92, 0.6], id: \.self) { width in
          Capsule().fill(TVPalette.surfaceRaised).frame(width: 648 * width, height: 28)
        }
      }
      .accessibilityHidden(true)
    } else if let text = page?.description, !text.isEmpty {
      Text(verbatim: text).font(TVType.body).foregroundStyle(TVPalette.textHigh).lineLimit(9)
        .focusable()
    }
  }
}

// Android TV's AvatarButton in the player's preference row: the channel's picture, which opens its panel.
struct TVChannelAvatarButton: View {
  let video: LiveVideoItem
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      ZStack {
        Circle().fill(TVPalette.surfaceRaised)
        Text(verbatim: String(video.uploaderName.prefix(1)).uppercased()).font(TVType.label).foregroundStyle(TVPalette.textHigh)
        if let url = video.uploaderAvatar { TVRemoteImage(url: url).clipShape(Circle()) }
      }
      .frame(width: 66, height: 66)
    }
    .buttonStyle(TVCircleButtonStyle())
    .accessibilityLabel(Text("\(video.uploaderName), shows the channel"))
  }
}
