import SwiftUI

struct TVJournalRows: View {
  let service: LiveBugReportsServiceProtocol
  @State private var lines: [String] = []
  @State private var bytes = 0
  @State private var status = Status.idle

  enum Status: Equatable {
    case idle, sending, sent, failed
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      TVSettingRow(systemImage: "paperplane", title: "Send the journal",
                   summary: "Sends journal.log to your instance as a bug report its admin can read.",
                   trailing: .value(statusText)) { send() }
        .disabled(status == .sending)
      TVSettingRow(systemImage: "arrow.clockwise", title: "Refresh", summary: "Shows the latest lines below.",
                   trailing: .value(ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file))) {
        Task { await load() }
      }
      ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
        Button {} label: {
          Text(verbatim: block).font(.system(size: 17, design: .monospaced)).lineLimit(nil)
            .frame(width: 1132, alignment: .leading)
        }
        .buttonStyle(TVJournalBlockStyle())
      }
    }
    .task { await load() }
  }

  private var blocks: [String] {
    stride(from: lines.count, to: 0, by: -5).map { end in
      lines[max(end - 5, 0)..<end].joined(separator: "\n")
    }
  }

  private var statusText: String {
    switch status {
    case .idle: ""
    case .sending: String(localized: "Sending")
    case .sent: String(localized: "Sent")
    case .failed: String(localized: "Not sent")
    }
  }

  private func load() async {
    lines = await TVJournal.shared.tail(300)
    bytes = await TVJournal.shared.size()
  }

  private func send() {
    status = .sending
    Task {
      TVJournal.note("journal", "sending to the server")
      let all = await TVJournal.shared.tail(4_000)
      let info = Bundle.main.infoDictionary
      let version = "\(info?["CFBundleShortVersionString"] as? String ?? "?") (\(info?["CFBundleVersion"] as? String ?? "?"))"
      let system = ProcessInfo.processInfo.operatingSystemVersionString
      do {
        let report = try await service.sendJournal(
          all, description: "Apple TV journal, TypeType \(version), tvOS \(system), \(all.count) lines",
          userAgent: "TypeType tvOS \(version)"
        )
        TVJournal.note("journal", "sent as report \(report.id)")
        status = .sent
      } catch {
        TVJournal.note("journal", "send failed: \(error.localizedDescription)")
        status = .failed
      }
      await load()
    }
  }
}

private struct TVJournalBlockStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    TVJournalBlock(configuration: configuration)
  }
}

private struct TVJournalBlock: View {
  let configuration: ButtonStyleConfiguration
  @Environment(\.isFocused) private var isFocused

  var body: some View {
    configuration.label
      .foregroundStyle(isFocused ? TVPalette.textHigh : TVPalette.textMid)
      .padding(.horizontal, 24).padding(.vertical, 12)
      .background(isFocused ? TVPalette.glassStrong : Color.clear, in: RoundedRectangle(cornerRadius: 14))
  }
}
