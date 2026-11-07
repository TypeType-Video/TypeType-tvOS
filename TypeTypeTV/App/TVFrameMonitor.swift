#if DEBUG
import QuartzCore

@MainActor
final class TVFrameMonitor: NSObject {
  private var link: CADisplayLink?
  private var last: CFTimeInterval = 0
  private var windowStart: CFTimeInterval = 0
  private var frames = 0
  private var missed = 0
  private var hitches = 0
  private var worst: CFTimeInterval = 0

  private static let window: CFTimeInterval = 5

  func startIfRequested() {
    guard link == nil, CommandLine.arguments.contains("--typetype-frame-monitor") else { return }
    let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
    link.add(to: .main, forMode: .common)
    self.link = link
  }

  @objc private func tick(_ link: CADisplayLink) {
    let now = link.timestamp
    defer { last = now }
    guard last > 0 else { windowStart = now; return }
    let interval = now - last
    let slot = max(link.duration, 1.0 / 120)
    frames += 1
    if interval > slot * 1.5 {
      hitches += 1
      missed += Int((interval / slot).rounded()) - 1
    }
    worst = max(worst, interval)
    guard now - windowStart >= Self.window else { return }
    let summary = "frames \(frames) missed \(missed) hitches \(hitches) worst \(Int(worst * 1_000)) ms"
    AppLogger.performance.notice("\(summary, privacy: .public)")
    windowStart = now
    frames = 0
    missed = 0
    hitches = 0
    worst = 0
  }
}
#endif
