import SwiftUI

struct TVChannelBanner: View {
  static let height: CGFloat = 520
  let url: URL?
  @ObservedObject var scroll: TVBannerScroll

  var body: some View {
    ZStack {
      if let url { TVRemoteImage(url: url).opacity(0.9 * (1 - scroll.fraction)) }
      LinearGradient(
        stops: [.init(color: TVPalette.ink.opacity(0.1), location: 0), .init(color: TVPalette.ink.opacity(0.55), location: 0.55),
                .init(color: TVPalette.ink, location: 1)],
        startPoint: .top, endPoint: .bottom
      )
    }
    .frame(height: Self.height)
    .frame(maxWidth: .infinity)
    .clipped()
  }
}

@MainActor
final class TVBannerScroll: ObservableObject {
  @Published var fraction: CGFloat = 0
}

extension View {
  func tvFadesBanner(_ scroll: TVBannerScroll) -> some View {
    modifier(TVBannerScrollReader(scroll: scroll))
  }
}

private struct TVBannerScrollReader: ViewModifier {
  let scroll: TVBannerScroll

  func body(content: Content) -> some View {
    if #available(tvOS 18.0, *) {
      content.onScrollGeometryChange(for: CGFloat.self) { geometry in
        let offset = geometry.contentOffset.y + geometry.contentInsets.top
        return (min(max(offset / TVChannelBanner.height, 0), 1) * 20).rounded() / 20
      } action: { _, fraction in
        scroll.fraction = fraction
      }
    } else {
      content
    }
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
