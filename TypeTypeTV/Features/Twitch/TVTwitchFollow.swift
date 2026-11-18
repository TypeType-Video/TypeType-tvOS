import SwiftUI

struct TVTwitchFollowButton: View {
  let login: String
  let account: LiveTwitchAccountServiceProtocol
  let onRoute: (TVRoute) -> Void
  @State private var linked: Bool?
  @State private var state: LiveTwitchFollowState?
  @State private var pending = false
  @State private var failed = false

  var body: some View {
    HStack(spacing: 24) {
      if linked == false {
        Button { onRoute(.twitch(.linkAccount)) } label: { Label("Follow", systemImage: "heart") }
          .buttonStyle(.tvPill)
          .accessibilityHint(Text("Link a Twitch account to follow channels."))
      } else if let state {
        Button { Task { await toggle(!state.following) } } label: {
          Label(state.following ? "Following" : "Follow", systemImage: state.following ? "heart.fill" : "heart")
        }
        .buttonStyle(state.following ? .tvPillEmphasized : .tvPill)
        .disabled(pending)
        .accessibilityLabel(state.following ? Text("Unfollow") : Text("Follow"))
        if let subscription = state.subscription {
          Label {
            Text(verbatim: ([LiveTwitchChatText.subscription(subscription)] + LiveTwitchChatText.subscriptionDetails(subscription)).joined(separator: " · "))
          } icon: { Image(systemName: "star.fill") }
            .font(TVType.meta)
            .foregroundStyle(TVPalette.accentSoft)
        }
      }
      if failed {
        Text("Twitch refused the follow.").font(TVType.meta).foregroundStyle(TVPalette.accentSoft)
      }
    }
    .task(id: login) {
      guard let status = try? await account.account() else { return }
      linked = status.linked
      if status.linked { state = try? await account.follow(login: login) }
    }
  }

  private func toggle(_ following: Bool) async {
    pending = true
    defer { pending = false }
    do {
      state = try await account.setFollow(login: login, following: following)
      failed = false
    } catch {
      failed = true
    }
  }
}

struct TVTwitchFollowedRows: View {
  let account: LiveTwitchAccountServiceProtocol
  let onPlay: (LiveVideoItem) -> Void
  let onRoute: (TVRoute) -> Void
  @State private var linked: Bool?
  @State private var live: [LiveTwitchStream] = []
  @State private var videos: [LiveTwitchVideo] = []
  @State private var channels: [LiveTwitchUser] = []

  var body: some View {
    VStack(alignment: .leading, spacing: 56) {
      if linked == false {
        Button { onRoute(.twitch(.linkAccount)) } label: { Label("Link a Twitch account", systemImage: "person.crop.circle.badge.plus") }
          .buttonStyle(.tvPill)
          .padding(.horizontal, TVDimens.safeStart)
          .accessibilityIdentifier("tv.twitch.link-account")
      }
      if !live.isEmpty {
        shelf("Live from channels you follow") {
          ForEach(live) { stream in
            TVTwitchStreamCard(stream: stream, width: 440) { onPlay(LiveTwitchPlayback.item(live: stream)) }
          }
        }
      }
      if !videos.isEmpty {
        shelf("Past broadcasts from channels you follow") {
          ForEach(videos) { video in
            TVTwitchMediaTile(title: video.title, previewURL: video.previewURL, duration: video.lengthSeconds, detail: video.owner.name) {
              onPlay(LiveTwitchPlayback.item(video: video))
            }
          }
        }
      }
      if !channels.isEmpty {
        shelf("Channels you follow") {
          ForEach(channels, id: \.login) { user in
            Button { onRoute(.twitch(.channel(user.login))) } label: {
              VStack(spacing: 14) {
                TVRemoteImage(url: LiveImageURLResolver.resolve(user.avatarURL))
                  .frame(width: 140, height: 140)
                  .clipShape(Circle())
                Text(verbatim: user.displayName).font(TVType.meta).lineLimit(1).frame(width: 180)
              }
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(Text(verbatim: user.displayName))
          }
        }
      }
    }
    .task { await load() }
  }

  private func shelf<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 24) {
      TVTwitchSectionTitle(title: title).padding(.leading, TVDimens.safeStart)
      ScrollView(.horizontal) {
        LazyHStack(alignment: .top, spacing: 40) { content() }
          .padding(.horizontal, TVDimens.safeStart)
          .padding(.vertical, 24)
      }
      .scrollClipDisabled()
    }
  }

  private func load() async {
    guard let status = try? await account.account() else { return }
    linked = status.linked
    guard status.linked else { return }
    async let followedLive = try? account.followedLive(after: nil)
    async let followedVideos = try? account.followedVideos(after: nil)
    async let followedChannels = try? account.followedChannels(after: nil)
    live = await followedLive?.items ?? []
    videos = await followedVideos?.items ?? []
    channels = await followedChannels?.items ?? []
  }
}
