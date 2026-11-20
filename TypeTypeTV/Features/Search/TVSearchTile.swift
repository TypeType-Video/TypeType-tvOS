import SwiftUI

struct TVSearchTile: View {
  enum Artwork {
    case wide
    case round
  }

  static let width: CGFloat = 392

  let id: String
  var entry: FocusState<String?>.Binding
  var video: LiveVideoItem?
  let image: URL?
  let artwork: Artwork
  let title: String
  let line: String
  let detail: String
  let badge: String?
  let onOpen: () -> Void
  @State private var menuOpenedAt: Date?

  var body: some View {
    VStack(alignment: artwork == .round ? .center : .leading, spacing: 18) {
      button
      VStack(alignment: artwork == .round ? .center : .leading, spacing: 4) {
        Text(verbatim: title)
          .font(TVType.title)
          .foregroundStyle(TVPalette.textHigh)
          .lineLimit(2)
          .multilineTextAlignment(artwork == .round ? .center : .leading)
        if !line.isEmpty { Text(verbatim: line).font(TVType.meta).foregroundStyle(TVPalette.textMid).lineLimit(1) }
        if !detail.isEmpty { Text(verbatim: detail).font(TVType.meta).foregroundStyle(TVPalette.textLow).lineLimit(1) }
      }
      .frame(width: Self.width, alignment: artwork == .round ? .center : .leading)
      .accessibilityHidden(true)
    }
    .frame(width: Self.width)
  }

  @ViewBuilder
  private var button: some View {
    if let video {
      base.tvVideoMenu(video, openedAt: $menuOpenedAt) { entry.wrappedValue = id }
    } else {
      base
    }
  }

  @ViewBuilder
  private var base: some View {
    switch artwork {
    case .wide:
      Button(action: open) { wide }
        .buttonStyle(.card)
        .focused(entry, equals: id)
        .accessibilityLabel(label)
    case .round:
      Button(action: open) {
        TVRemoteImage(url: image).frame(width: 220, height: 220).clipShape(Circle())
      }
      .buttonStyle(.borderless)
      .focused(entry, equals: id)
      .accessibilityLabel(label)
    }
  }

  private var wide: some View {
    ZStack(alignment: .bottomTrailing) {
      TVRemoteImage(url: image)
      if let badge {
        Text(verbatim: badge).font(TVType.label).foregroundStyle(TVPalette.textHigh)
          .padding(.horizontal, 12).padding(.vertical, 6)
          .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 8))
          .padding(14)
      }
    }
    .frame(width: Self.width, height: Self.width * 9 / 16)
  }

  private var label: Text {
    Text(verbatim: line.isEmpty ? title : "\(title), \(line)")
  }

  private func open() {
    if !TVVideoMenuTarget.swallowsRelease(menuOpenedAt) { onOpen() }
  }
}

struct TVResultSkeleton: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      RoundedRectangle(cornerRadius: TVDimens.cardRadius).fill(TVPalette.surfaceRaised)
        .frame(width: TVSearchTile.width, height: TVSearchTile.width * 9 / 16)
      Capsule().fill(TVPalette.surfaceRaised).frame(width: 320, height: 26)
      Capsule().fill(TVPalette.surfaceRaised).frame(width: 220, height: 20)
    }
    .accessibilityHidden(true)
  }
}
