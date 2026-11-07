import SwiftUI

struct TVReconnectView: View {
  @ObservedObject var coordinator: RootCoordinator
  @State private var failedAttempts = 0
  @State private var retryNow = 0
  @FocusState private var retryFocused: Bool

  var body: some View {
    TVAuthScaffold(title: String(localized: "Connecting to your server"), subtitle: coordinator.selectedServer?.baseURL?.host ?? "") {
      VStack(alignment: .leading, spacing: 36) {
        Text(failedAttempts == 0 ? "Checking your session." :
               "The server is not answering. The app keeps trying and continues as soon as it is back.")
          .font(TVType.body).foregroundStyle(TVPalette.textMid)
        HStack(spacing: 24) {
          Button { retryNow += 1 } label: { Label("Try again", systemImage: "arrow.clockwise") }
            .buttonStyle(.tvPillEmphasized)
            .focused($retryFocused)
          Button { coordinator.showServerSetup() } label: { Label("Change instance", systemImage: "arrow.left.arrow.right") }
            .buttonStyle(.tvPill)
        }
      }
    }
    .onAppear { retryFocused = true }
    .task(id: retryNow) { await keepTrying(waitFirst: retryNow == 0) }
  }

  private func keepTrying(waitFirst: Bool) async {
    var wait = waitFirst
    while !Task.isCancelled {
      if wait, (try? await Task.sleep(for: Self.delay(after: failedAttempts))) == nil { return }
      wait = true
      guard let server = coordinator.selectedServer, let baseURL = server.baseURL else { return }
      do {
        _ = try await coordinator.dependencies.serverProbeService.probe(baseURL: baseURL)
        Task { [coordinator] in await coordinator.selectServer(server) }
        return
      } catch is CancellationError {
        return
      } catch {
        failedAttempts += 1
      }
    }
  }

  static func delay(after attempts: Int) -> Duration {
    .milliseconds(min(2_000 << min(max(attempts - 1, 0), 4), 30_000))
  }
}
