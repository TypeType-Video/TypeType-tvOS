import Foundation

enum LiveSeekMath {
  static let jumpMilliseconds: Int64 = 10_000
  private static let minimumStep: Int64 = 5_000
  private static let minimumCap: Int64 = 10_000
  private static let capDivisor: Int64 = 40
  private static let growth = 1.05
  private static let maximumGrowthPresses = 200

  // Every scrub starts with five-second steps and each press moves a little further than the last, up to a share of
  // the video: fifteen seconds for ten minutes, fifteen minutes for a ten-hour stream.
  static func scrubStep(press: Int, durationMilliseconds: Int64) -> Int64 {
    let cap = max(durationMilliseconds / capDivisor, minimumCap)
    let grown = Double(minimumStep) * pow(growth, Double(min(max(press, 0), maximumGrowthPresses)))
    return min(max(Int64(grown), minimumStep), cap)
  }

  static func target(current: Int64, delta: Int64, duration: Int64) -> Int64 {
    min(max(current + delta, 0), max(duration, 0))
  }

  static func fraction(position: Int64, duration: Int64) -> Double {
    guard duration > 0 else { return 0 }
    return min(max(Double(position) / Double(duration), 0), 1)
  }
}

struct LiveScrubState: Equatable {
  private(set) var target: Int64?
  private(set) var presses = 0
  private var direction = 0

  var isActive: Bool { target != nil }

  // Pressing on in the same direction keeps the grown step, so it goes faster; turning back halves it, so the
  // target can be reached precisely after overshooting.
  mutating func move(current: Int64, direction: Int, duration: Int64) {
    if self.direction != 0, direction != self.direction { presses /= 2 }
    self.direction = direction
    let step = LiveSeekMath.scrubStep(press: presses, durationMilliseconds: duration)
    presses += 1
    target = LiveSeekMath.target(current: target ?? current, delta: Int64(direction) * step, duration: duration)
  }

  mutating func commit() -> Int64? {
    defer { cancel() }
    return target
  }

  mutating func cancel() {
    target = nil
    presses = 0
    direction = 0
  }
}
