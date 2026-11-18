import SwiftUI

struct TVServerStatusBanner: View {
  @ObservedObject var monitor: LiveServerStatusMonitor

  var body: some View {
    Group {
      if let message = monitor.message {
        HStack(spacing: 14) {
          if monitor.isWaiting {
            ProgressView()
          } else {
            Image(systemName: monitor.status.notice != nil ? "wrench.and.screwdriver.fill" : "checkmark.circle.fill")
              .foregroundStyle(monitor.status.notice != nil ? TVPalette.textHigh : TVPalette.success)
          }
          Text(verbatim: message).font(TVType.meta).foregroundStyle(TVPalette.textHigh)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 14)
        .background(TVPalette.surfaceRaised.opacity(0.95), in: Capsule())
        .transition(.move(edge: .top).combined(with: .opacity))
        .accessibilityElement(children: .combine)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .padding(.top, 40)
    .allowsHitTesting(false)
    .animation(.easeOut(duration: 0.25), value: monitor.message)
  }
}

struct TVServerStatusOverlay: ViewModifier {
  let monitor: LiveServerStatusMonitor?
  var runs = false
  @Environment(\.scenePhase) private var scenePhase

  func body(content: Content) -> some View {
    if let monitor {
      content
        .overlay { TVServerStatusBanner(monitor: monitor) }
        .task(id: scenePhase == .active) {
          guard runs, scenePhase == .active else { return }
          await monitor.run()
        }
    } else {
      content
    }
  }
}
