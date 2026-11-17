import SwiftUI

struct TVTwitchRewindRows: View {
  let archive: LiveTwitchArchive
  let onRewind: (TimeInterval) -> Void
  private static let steps: [TimeInterval] = [60, 300, 900, 1_800, 3_600]
  @FocusState private var focused: TimeInterval?

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      let range = LiveTwitchArchiveTime.position(startedAt: archive.startedAt, now: context.date) ?? 0
      let steps = Self.steps.filter { LiveTwitchArchiveTime.rewindTarget(range - $0, range: range) != nil }
      VStack(alignment: .leading, spacing: 12) {
        ForEach(steps, id: \.self) { step in
          row(Text("\(LiveTwitchFormat.clock(step)) behind live"), id: step) { onRewind(range - step) }
        }
        if range > LiveTwitchArchiveTime.minimumRewind {
          row(Text("From the start of the live"), id: .infinity) { onRewind(0) }
        }
        if steps.isEmpty, range <= LiveTwitchArchiveTime.minimumRewind {
          Text("The recording of this live is not long enough yet.").font(TVType.body).foregroundStyle(TVPalette.textMid)
        }
      }
    }
    .onAppear { Task { focused = Self.steps.first } }
  }

  private func row(_ label: Text, id: TimeInterval, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      label.font(TVType.title).frame(maxWidth: .infinity, alignment: .leading)
    }
    .buttonStyle(.tvPill)
    .focused($focused, equals: id)
  }
}
