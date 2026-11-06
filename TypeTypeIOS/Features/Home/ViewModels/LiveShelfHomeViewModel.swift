import Combine
import Foundation

@MainActor
final class LiveShelfHomeViewModel: ObservableObject {
  enum State: Equatable {
    case loading
    case loaded(LiveShelfHome)
    case failed(String)
  }

  @Published private(set) var state = State.loading
  private let load: () async throws -> LiveShelfHome
  private var generation = 0

  init(load: @escaping () async throws -> LiveShelfHome) {
    self.load = load
  }

  convenience init(loader: LiveShelfHomeLoader) {
    self.init(load: loader.load)
  }

  func loadIfNeeded() async {
    guard case .loading = state else { return }
    await reload()
  }

  func reload() async {
    generation += 1
    let current = generation
    if case .failed = state { state = .loading }
    do {
      let home = try await load()
      guard current == generation else { return }
      state = .loaded(home)
    } catch is CancellationError {
      return
    } catch {
      guard current == generation else { return }
      state = .failed(LiveHomeViewModel.message(for: error))
    }
  }
}
