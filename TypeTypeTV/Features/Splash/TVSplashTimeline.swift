import Foundation

// Every time is in milliseconds from the first frame, as in the Android TV intro. The startup sound is built on the
// same numbers: each hop lands on a note and the last landing is the chord, so a change here needs a new sound.
enum TVSplashTimeline {
  static let total: Double = 6_000
  static let hops = 13
  private static let cursorIn: Double = 400
  private static let traceStart: Double = 450
  private static let hop: Double = 210
  private static let hopMotion: Double = 0.85
  static let burst: Double = traceStart + Double(hops - 1) * hop + hop * hopMotion
  private static let burstRise: Double = 90
  private static let burstFall: Double = 900
  private static let punchRise: Double = 80
  private static let punchDecay: Double = 180
  private static let shakeLength: Double = 500
  private static let shakeDecay: Double = 150
  private static let shakeSpeed: Double = 0.11
  private static let settleStart: Double = 3_250
  private static let settleLength: Double = 900
  private static let writeStart: Double = 3_700
  private static let writeLength: Double = 1_500
  private static let blink: Double = 200
  private static let exitStart: Double = 5_600

  private static let glide = TVCubicBezier(0.2, 0, 0, 1)
  private static let hopCurve = TVCubicBezier(0.4, 0, 0.2, 1)
  private static let pen = TVCubicBezier(0.45, 0, 0.3, 1)

  static func cursorAppear(_ time: Double) -> Double { glide.value(fraction(time, 0, cursorIn)) }

  static func traceProgress(_ time: Double) -> Double {
    guard time > traceStart else { return 0 }
    let elapsed = time - traceStart
    let step = Int(elapsed / hop)
    if step >= hops { return Double(hops) }
    return Double(step) + hopCurve.value(fraction(elapsed - Double(step) * hop, 0, hop * hopMotion))
  }

  static func burstAmount(_ time: Double) -> Double {
    if time < burst { return 0 }
    if time < burst + burstRise { return (time - burst) / burstRise }
    return 1 - glide.value(fraction(time, burst + burstRise, burst + burstRise + burstFall))
  }

  static func punch(_ time: Double) -> Double {
    let since = time - burst
    if since < 0 { return 0 }
    if since < punchRise { return glide.value(since / punchRise) }
    return exp(-(since - punchRise) / punchDecay)
  }

  static func shake(_ time: Double) -> CGSize {
    let since = time - burst
    guard since >= 0, since <= shakeLength else { return .zero }
    let amount = exp(-since / shakeDecay)
    return CGSize(width: sin(since * shakeSpeed) * amount, height: cos(since * shakeSpeed * 1.3) * amount)
  }

  static func settle(_ time: Double) -> Double { glide.value(fraction(time, settleStart, settleStart + settleLength)) }
  static func writeProgress(_ time: Double) -> Double { pen.value(fraction(time, writeStart, writeStart + writeLength)) }

  static func textCursorShown(_ time: Double) -> Bool {
    let written = writeStart + writeLength
    return time >= written && time < exitStart && Int((time - written) / blink) % 2 == 0
  }

  static func exitAlpha(_ time: Double) -> Double { 1 - fraction(time, exitStart, total) }

  private static func fraction(_ time: Double, _ start: Double, _ end: Double) -> Double {
    min(max((time - start) / (end - start), 0), 1)
  }
}

// The cubic-bezier easing curves of CSS and Compose: x is time, y is progress.
struct TVCubicBezier {
  let x1: Double, y1: Double, x2: Double, y2: Double

  init(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) {
    (self.x1, self.y1, self.x2, self.y2) = (x1, y1, x2, y2)
  }

  func value(_ x: Double) -> Double {
    guard x > 0 else { return 0 }
    guard x < 1 else { return 1 }
    var low = 0.0, high = 1.0, t = x
    for _ in 0..<24 {
      t = (low + high) / 2
      if point(t, x1, x2) < x { low = t } else { high = t }
    }
    return point(t, y1, y2)
  }

  private func point(_ t: Double, _ a: Double, _ b: Double) -> Double {
    let u = 1 - t
    return 3 * u * u * t * a + 3 * u * t * t * b + t * t * t
  }
}
