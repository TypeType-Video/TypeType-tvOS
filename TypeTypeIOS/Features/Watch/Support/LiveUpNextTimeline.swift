import Foundation

// Android TV's UpNextTimeline: when the Up next card shows before the end, and how full its countdown is.
enum LiveUpNextTimeline {
  private static let minimumDuration: TimeInterval = 20
  private static let minimumWindow: TimeInterval = 3

  static func window(duration: TimeInterval, countdownSeconds: Int) -> TimeInterval {
    guard duration >= minimumDuration else { return 0 }
    return max(min(TimeInterval(max(countdownSeconds, 1)), duration / 3), minimumWindow)
  }

  static func remaining(position: TimeInterval, duration: TimeInterval) -> TimeInterval {
    min(max(duration - position, 0), max(duration, 0))
  }

  static func inWindow(position: TimeInterval, duration: TimeInterval, window: TimeInterval) -> Bool {
    window > 0 && duration > 0 && remaining(position: position, duration: duration) <= window
  }

  static func fill(position: TimeInterval, duration: TimeInterval, window: TimeInterval) -> Double {
    guard window > 0 else { return 0 }
    return min(max(1 - remaining(position: position, duration: duration) / window, 0), 1)
  }

  static func secondsLeft(position: TimeInterval, duration: TimeInterval) -> Int {
    Int(remaining(position: position, duration: duration).rounded(.up))
  }
}
