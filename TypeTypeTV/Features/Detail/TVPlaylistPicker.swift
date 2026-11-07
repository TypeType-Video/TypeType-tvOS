import SwiftUI

// A floating card over the page. It always holds a focusable row, so Menu reaches it and closes only the card;
// with no row the press went to the page behind and closed that too.
struct TVPlaylistPicker: View {
  @ObservedObject var actions: LiveVideoQuickActionsViewModel
  let onClose: () -> Void
  @FocusState private var focused: String?

  private static let closeID = "close"

  var body: some View {
    HStack {
      Spacer()
      VStack(alignment: .leading, spacing: 24) {
        Text("Add to a playlist").font(TVType.headline).foregroundStyle(TVPalette.textHigh)
        if actions.playlists.isEmpty {
          Text("You have no playlist yet.").font(TVType.body).foregroundStyle(TVPalette.textMid)
          Button(action: onClose) { Label("Close", systemImage: "xmark").frame(width: 560, alignment: .leading) }
            .buttonStyle(.tvPill)
            .focused($focused, equals: Self.closeID)
        }
        ScrollView(.vertical) {
          VStack(alignment: .leading, spacing: 14) {
            ForEach(actions.playlists) { playlist in
              Button {
                Task { await actions.addToPlaylist(playlist) }
                onClose()
              } label: {
                Label(playlist.name, systemImage: "music.note.list").frame(width: 560, alignment: .leading)
              }
              .buttonStyle(.tvPill)
              .focused($focused, equals: playlist.id)
            }
          }
          .padding(.vertical, 12)
        }
        .scrollClipDisabled()
        .frame(maxHeight: 640)
      }
      .padding(48)
      .frame(width: 720)
      // The card is as tall as its rows; a long list scrolls inside it.
      .fixedSize(horizontal: false, vertical: true)
      .tvGlassPanel(cornerRadius: 44)
      .frame(maxHeight: .infinity, alignment: .top)
      .padding(.vertical, 40)
      .padding(.trailing, 64)
    }
    // The card starts under the tab bar, which stays drawn above the page.
    .ignoresSafeArea(edges: [.horizontal, .bottom])
    .focusSection()
    .onExitCommand(perform: onClose)
    .onAppear { focused = actions.playlists.first?.id ?? Self.closeID }
  }
}

extension View {
  // Frosted glass: the page shows blurred through a dark tint, with a light rim and a shadow to lift the card.
  func tvGlassPanel(cornerRadius: CGFloat) -> some View {
    let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    return background(TVPalette.surface.opacity(0.72), in: shape)
      .background(.ultraThinMaterial, in: shape)
      .overlay(shape.strokeBorder(TVPalette.textHigh.opacity(0.12), lineWidth: 1.5))
      .shadow(color: .black.opacity(0.45), radius: 40, y: 16)
  }
}
