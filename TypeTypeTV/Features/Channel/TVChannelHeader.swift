import SwiftUI

// Android TV's ChannelBanner and ChannelHeader: the banner across the top, the avatar over its lower edge, the name,
// subscribers and description, then Subscribe and the more button.
struct TVChannelBanner: View {
  let url: URL?

  var body: some View {
    ZStack {
      if let url { TVRemoteImage(url: url).opacity(0.9) }
      LinearGradient(
        stops: [.init(color: TVPalette.ink.opacity(0.1), location: 0), .init(color: TVPalette.ink.opacity(0.55), location: 0.55),
                .init(color: TVPalette.ink, location: 1)],
        startPoint: .top, endPoint: .bottom
      )
    }
    .frame(height: 520)
    .frame(maxWidth: .infinity)
    .clipped()
  }
}

struct TVChannelHeader: View {
  @ObservedObject var model: LiveChannelViewModel
  let page: LiveChannelPage
  var focus: FocusState<TVChannelFocus?>.Binding
  let onMore: () -> Void

  var body: some View {
    HStack(alignment: .bottom, spacing: 48) {
      ZStack {
        Circle().fill(TVPalette.surfaceRaised)
        Text(verbatim: String(page.name.prefix(1)).uppercased()).font(TVType.headline).foregroundStyle(TVPalette.textHigh)
        TVRemoteImage(url: page.avatar).clipShape(Circle())
      }
      .frame(width: 208, height: 208)
      .padding(8)
      .background(TVPalette.ink, in: Circle())
      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 20) {
          Text(verbatim: page.name).font(TVType.display).foregroundStyle(TVPalette.textHigh).lineLimit(1)
          if page.isVerified {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 44)).foregroundStyle(TVPalette.textMid)
              .accessibilityLabel(Text("Verified channel"))
          }
        }
        if page.subscriberCount > 0 {
          Text(verbatim: LiveVideoMetadataFormatter.subscribers(page.subscriberCount)).font(TVType.meta).foregroundStyle(TVPalette.textMid)
        }
        if !page.description.isEmpty {
          Text(verbatim: page.description).font(TVType.body).foregroundStyle(TVPalette.textMid).lineLimit(2)
            .frame(maxWidth: 900, alignment: .leading)
        }
      }
      .padding(.bottom, 8)
      Spacer(minLength: 0)
      VStack(alignment: .trailing, spacing: 12) {
        HStack(spacing: 20) {
          Button { Task { await model.toggleSubscription() } } label: {
            Label(model.isSubscribed ? "Subscribed" : "Subscribe", systemImage: model.isSubscribed ? "checkmark" : "bell")
          }
          .buttonStyle(model.isSubscribed ? .tvPill : .tvPillEmphasized)
          .disabled(model.isChangingSubscription)
          TVCircleButton(systemImage: "ellipsis", label: "More options", action: onMore)
            .focused(focus, equals: .more)
        }
        .fixedSize()
        if let error = model.subscriptionError {
          Text(verbatim: error).font(TVType.meta).foregroundStyle(TVPalette.accent).lineLimit(2).frame(width: 520, alignment: .trailing)
        }
      }
      .padding(.bottom, 8)
    }
    .padding(.horizontal, TVDimens.safeStart)
    .focusSection()
  }
}
