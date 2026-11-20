import SwiftUI

struct TVTwitchChatActions: View {
  @ObservedObject var model: LiveTwitchChatViewModel
  @FocusState private var focused: String?

  var body: some View {
    HStack {
      Spacer()
      VStack(alignment: .leading, spacing: 24) {
        Text("Chat").font(TVType.headline).foregroundStyle(TVPalette.textHigh)
        ScrollView(.vertical) {
          VStack(alignment: .leading, spacing: 18) { rows }
            .padding(12)
        }
        .padding(.horizontal, -12)
      }
      .padding(.horizontal, 56)
      .padding(.top, 90)
      .padding(.bottom, 56)
      .frame(width: 760)
      .frame(maxHeight: .infinity, alignment: .top)
      .background(TVPalette.surface.opacity(0.96))
    }
    .ignoresSafeArea()
    .focusSection()
    .onAppear { Task { focused = model.canWrite ? "write" : "pinned" } }
  }

  @ViewBuilder
  private var rows: some View {
    if model.canWrite {
      TextField("Send a message", text: $model.draft)
        .onSubmit { Task { await model.send() } }
        .frame(width: 560)
        .focused($focused, equals: "write")
        .disabled(model.isSending)
    } else {
      Text("Link a Twitch account to chat.").font(TVType.body).foregroundStyle(TVPalette.textMid)
    }
    if let notice = model.notice {
      Text(verbatim: notice).font(TVType.meta).foregroundStyle(TVPalette.accentSoft)
    }
    if let poll = model.visiblePoll {
      Text(verbatim: poll.title).font(TVType.title).foregroundStyle(TVPalette.textHigh)
      ForEach(poll.choices) { choice in
        let percent = LiveTwitchChatText.percent(choice, in: poll)
        Button { Task { await model.vote(choice) } } label: {
          HStack {
            Text(verbatim: choice.title)
            Spacer()
            Text(verbatim: "\(percent)%").monospacedDigit().opacity(0.7)
          }
          .frame(width: 560, alignment: .leading)
        }
        .buttonStyle(.tvPill)
        .disabled(!model.canWrite || model.votedPollID == poll.id || !poll.isActive)
        .focused($focused, equals: choice.id)
        .accessibilityLabel(Text("Vote for \(choice.title) (\(percent)%)"))
      }
      (poll.isActive ? Text("\(poll.votes) votes") : Text("Poll ended")).font(TVType.meta).foregroundStyle(TVPalette.textMid)
    }
    if let pinned = model.visiblePinned {
      VStack(alignment: .leading, spacing: 8) {
        if let by = pinned.pinnedBy { Text("Pinned by \(by)").font(TVType.label).foregroundStyle(TVPalette.textMid) }
        Text(verbatim: "\(pinned.author): \(pinned.text)").font(TVType.body).foregroundStyle(TVPalette.textHigh)
      }
      .focusable()
      .focused($focused, equals: "pinned")
      .accessibilityElement(children: .combine)
      .accessibilityLabel(Text("Pinned message"))
    }
  }
}
