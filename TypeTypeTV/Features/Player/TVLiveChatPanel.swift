import SwiftUI

struct TVLiveChatPanel: View {
  @ObservedObject var model: TVLiveChatModel
  let layout: TVChatLayout
  let density: TVChatDensity
  let dimmed: Bool
  var connects = true

  var body: some View {
    TVChatSurface(layout: layout, dimmed: dimmed) {
      lines
    }
    .onAppear { if connects { model.start() } }
    .onChange(of: connects) { _, connects in if connects { model.start() } }
    .onDisappear { model.stop() }
  }

  private var lines: some View {
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
        TVNewestThatFit(spacing: density.spacing) {
          ForEach(model.buffer.messages) { message in
            Text(Self.line(message))
              .font(density.font)
              .lineLimit(3)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
      }
    }
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
