import SwiftUI

struct TVChannelSearchPanel: View {
  let channelName: String
  let initial: String
  let onSearch: (String) -> Void
  let onClose: () -> Void
  @State private var query = ""
  @FocusState private var firstKey: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Search \(channelName)").font(TVType.title).foregroundStyle(TVPalette.textHigh)
      TVQueryField(query: query, recent: [])
      TVSearchKeyboard(query: $query, firstKey: $firstKey)
      Button {
        onSearch(query)
        onClose()
      } label: {
        Label("Search", systemImage: "magnifyingglass").frame(maxWidth: .infinity)
      }
      .buttonStyle(.tvPillEmphasized)
    }
    .frame(width: 960)
    .padding(40)
    .background(TVPalette.surface, in: RoundedRectangle(cornerRadius: TVDimens.panelRadius))
    .padding(.top, 150)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(TVPalette.ink.opacity(0.8).ignoresSafeArea())
    .focusSection()
    .defaultFocus($firstKey, true)
    .onExitCommand(perform: onClose)
    .onAppear { query = initial }
  }
}

struct TVChannelMoreMenu: View {
  let channel: LiveContentControlItem
  let service: LiveContentControlsServiceProtocol
  let onClose: () -> Void
  @State private var blocked: Bool?
  @State private var confirming = false
  @State private var failed = false
  @FocusState private var first: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      if confirming {
        Text("Block this channel?").font(TVType.headline).foregroundStyle(TVPalette.textHigh)
        Text("Its videos will disappear from the home, search and related lists on all your devices.")
          .font(TVType.body).foregroundStyle(TVPalette.textMid).frame(width: 760, alignment: .leading)
        HStack(spacing: 20) {
          Button("Block channel") { Task { await change(block: true) } }.buttonStyle(.tvPillEmphasized).focused($first)
          Button("Cancel", action: onClose).buttonStyle(.tvPill)
        }
      } else if let blocked {
        Button {
          if blocked { Task { await change(block: false) } } else { confirming = true }
        } label: {
          Label(blocked ? "Unblock channel" : "Block channel", systemImage: blocked ? "checkmark.circle" : "nosign")
            .frame(width: 560, alignment: .leading)
        }
        .buttonStyle(.tvPill)
        .focused($first)
      } else {
        ProgressView()
      }
      if failed {
        Text("The change could not be saved. Check the connection and try again.").font(TVType.meta).foregroundStyle(TVPalette.accent)
      }
    }
    .padding(56)
    .background(TVPalette.surface, in: RoundedRectangle(cornerRadius: TVDimens.panelRadius))
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(TVPalette.ink.opacity(0.8).ignoresSafeArea())
    .focusSection()
    .onExitCommand(perform: onClose)
    .task {
      do {
        blocked = try await service.items(kind: .blockedChannels).contains { $0.url == channel.url }
      } catch {
        failed = true
        blocked = false
      }
      first = true
    }
    .onChange(of: confirming) { _, _ in Task { first = true } }
  }

  private func change(block: Bool) async {
    failed = false
    do {
      if block {
        _ = try await service.add(kind: .blockedChannels, item: channel)
      } else {
        try await service.remove(kind: .blockedChannels, url: channel.url)
      }
      onClose()
    } catch {
      failed = true
    }
  }
}
