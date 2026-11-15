import SwiftUI

struct TVEndScreenLayer: View {
  let elements: [LiveEndScreenElement]
  let videoAspectRatio: CGFloat
  let focused: Bool
  var focus: FocusState<TVPlayerFocus?>.Binding
  let onOpen: (LiveEndScreenElement) -> Void

  var body: some View {
    GeometryReader { proxy in
      let frame = LiveEndScreenElement.videoFrame(in: proxy.size, videoAspectRatio: videoAspectRatio)
      ForEach(elements) { element in
        let box = element.box(in: frame)
        Button { onOpen(element) } label: {
          ZStack {
            TVPalette.ink.opacity(0.6)
            TVRemoteImage(url: LiveImageURLResolver.resolve(element.thumbnailURL), placeholder: false)
          }
        }
        .buttonStyle(TVEndScreenCardStyle(title: element.kind == .channel ? nil : element.title, round: element.kind == .channel))
        .focused(focus, equals: .endScreen(element.id))
        .disabled(!focused)
        .frame(width: box.width, height: box.height)
        .position(x: box.midX, y: box.midY)
        .accessibilityLabel(Self.label(element))
        .accessibilityHint(Self.hint(element))
      }
      if !focused {
        HStack(spacing: 10) {
          Image(systemName: "chevron.up")
          Text("Creator cards")
        }
        .font(TVType.label)
        .foregroundStyle(TVPalette.ink)
        .padding(.horizontal, 18).padding(.vertical, 8)
        .background(TVPalette.textHigh, in: Capsule())
        .position(x: frame.midX, y: frame.maxY - 64)
        .accessibilityHidden(true)
      }
    }
    .ignoresSafeArea()
  }

  private static func label(_ element: LiveEndScreenElement) -> Text {
    switch element.kind {
    case .playlist: Text("Playlist: \(element.title)")
    case .channel: Text("Channel: \(element.title)")
    default: Text("Video: \(element.title)")
    }
  }

  private static func hint(_ element: LiveEndScreenElement) -> Text {
    switch element.kind {
    case .playlist: Text("Opens this playlist.")
    case .channel: Text("Opens this channel.")
    default: Text("Plays this video.")
    }
  }
}

private struct TVEndScreenCardStyle: ButtonStyle {
  let title: String?
  let round: Bool

  func makeBody(configuration: Configuration) -> some View {
    TVEndScreenCardBody(configuration: configuration, title: title, round: round)
  }
}

private struct TVEndScreenCardBody: View {
  let configuration: ButtonStyleConfiguration
  let title: String?
  let round: Bool
  @Environment(\.isFocused) private var isFocused

  var body: some View {
    configuration.label
      .overlay(alignment: .bottomLeading) {
        if isFocused, let title, !title.isEmpty {
          Text(verbatim: title)
            .font(TVType.meta)
            .foregroundStyle(TVPalette.textHigh)
            .lineLimit(2)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(TVPalette.ink.opacity(0.8))
        }
      }
      .clipShape(shape)
      .overlay(shape.stroke(isFocused ? TVPalette.accent : TVPalette.textHigh.opacity(0.35), lineWidth: isFocused ? 4 : 1))
      .scaleEffect(isFocused ? TVDimens.focusScaleSmall : 1)
      .animation(.easeOut(duration: 0.14), value: isFocused)
  }

  private var shape: AnyShape {
    round ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
  }
}
