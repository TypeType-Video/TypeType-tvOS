import SwiftUI

// The column next to the picture while a YouTube live plays. It never takes the focus: the remote keeps
// driving the player.
struct TVLiveChatPanel: View {
  static let width: CGFloat = 480

  @ObservedObject var model: TVLiveChatModel
  // The control bar keeps the full width; the newest lines stay above it while it is shown.
  let underControls: Bool
  // Opened while the live starts, the chat made the live fail (CoreMedia -16845, three times out of three on the
  // simulator); opened once the live plays, both run. The player says when.
  var connects = true

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(spacing: 10) {
        Circle()
          .fill(model.buffer.status == .unavailable ? TVPalette.textLow : TVPalette.accent)
          .frame(width: 10, height: 10)
        Text("LIVE CHAT").font(TVType.label).tracking(3).foregroundStyle(TVPalette.textMid)
      }
      if let status = statusText {
        Text(verbatim: status).font(TVType.meta).foregroundStyle(TVPalette.textMid)
        Spacer(minLength: 0)
      } else {
        TVNewestThatFit(spacing: 10) {
          ForEach(model.buffer.messages) { message in
            Text(Self.line(message))
              .font(TVType.body)
              .lineLimit(3)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
      }
    }
    .padding(.leading, 28)
    .padding(.trailing, TVDimens.safeEnd)
    .padding(.top, 92)
    .padding(.bottom, underControls ? 220 : 80)
    .frame(width: Self.width, alignment: .leading)
    .frame(maxHeight: .infinity)
    // Opaque: a translucent column over moving video is blended again on every frame.
    .background(TVPalette.surface.ignoresSafeArea())
    .accessibilityHidden(true)
    .onAppear { if connects { model.start() } }
    .onChange(of: connects) { _, connects in if connects { model.start() } }
    .onDisappear { model.stop() }
  }

  private var statusText: String? {
    switch model.buffer.status {
    case .unavailable: return String(localized: "Live chat is not available for this stream")
    case .connecting: return String(localized: "Connecting to the live chat")
    case .connected, .ended: return model.buffer.messages.isEmpty ? String(localized: "No messages yet") : nil
    }
  }

  static func line(_ message: LiveChatMessage) -> AttributedString {
    var line = AttributedString()
    if !message.author.isEmpty {
      var author = AttributedString(message.author + "  ")
      author.foregroundColor = message.moderator ? TVPalette.accent : TVPalette.accentSoft
      line += author
    }
    var text = AttributedString(message.text)
    text.foregroundColor = TVPalette.textHigh
    line += text
    return line
  }
}

// Stacks the lines from the bottom and leaves out any line that would only be partly visible at the top.
struct TVNewestThatFit: Layout {
  var spacing: CGFloat

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    proposal.replacingUnspecifiedDimensions()
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    var y = bounds.maxY
    var used: CGFloat = 0
    var fits = true
    for subview in subviews.reversed() {
      let size = subview.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
      let needed = used + size.height + (used > 0 ? spacing : 0)
      fits = fits && needed <= bounds.height
      guard fits else {
        // Out of reach and clipped by the container.
        subview.place(at: CGPoint(x: bounds.minX, y: bounds.maxY + 10_000), anchor: .topLeading, proposal: .zero)
        continue
      }
      used = needed
      y -= size.height
      subview.place(at: CGPoint(x: bounds.minX, y: y), anchor: .topLeading, proposal: ProposedViewSize(width: bounds.width, height: size.height))
      y -= spacing
    }
  }
}
