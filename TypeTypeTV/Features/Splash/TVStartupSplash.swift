import AVFoundation
import SwiftUI

struct TVStartupSplash: View {
  let onFinished: () -> Void
  @State private var start: Date?
  @State private var chime: AVAudioPlayer?

  private let mark = TVSplashMark()
  private let wordmark = TVSplashWordmark()
  private static let traceSize: CGFloat = 500
  private static let finalSize: CGFloat = 208
  private static let wordCap: CGFloat = 92
  private static let wordGap: CGFloat = 60
  private static let shakeReach: CGFloat = 16
  private static let punchGrow = 0.14
  private static let prism: [(Color, CGFloat, CGFloat, CGFloat)] = [
    (Color(hex24: 0xFF3B3B), -1.5, 0, 0.05), (Color(hex24: 0xFF4FD8), 0.2, -0.8, 0.11), (Color(hex24: 0x5B6CFF), 1.5, 0.4, 0.17),
  ]

  var body: some View {
    TimelineView(.animation) { timeline in
      let time = start.map { timeline.date.timeIntervalSince($0) * 1_000 } ?? 0
      Canvas { context, size in draw(context, size: size, time: time) }
        .opacity(TVSplashTimeline.exitAlpha(time))
        .onChange(of: time >= TVSplashTimeline.total) { _, done in if done { finish() } }
    }
    .background(TVPalette.ink)
    .ignoresSafeArea()
    .accessibilityElement()
    .accessibilityLabel(Text(verbatim: "TypeType"))
    .onAppear(perform: begin)
  }

  private func begin() {
    guard start == nil else { return }
    if let url = Bundle.main.url(forResource: "startup_chime", withExtension: "m4a"),
      let player = try? AVAudioPlayer(contentsOf: url) {
      player.play()
      chime = player
    }
    start = .now
  }

  private func finish() {
    start = nil
    onFinished()
  }

  private func draw(_ context: GraphicsContext, size: CGSize, time: Double) {
    var context = context
    let shake = TVSplashTimeline.shake(time)
    context.translateBy(x: shake.width * Self.shakeReach, y: shake.height * Self.shakeReach)
    let center = CGPoint(x: size.width / 2, y: size.height / 2)
    let letterUnit = Self.wordCap / TVSplashGeometry.cap
    let rowWidth = Self.finalSize + Self.wordGap + TVSplashGeometry.wordWidth * letterUnit
    let finalCenter = CGPoint(x: center.x - rowWidth / 2 + Self.finalSize / 2, y: center.y)
    let settle = CGFloat(TVSplashTimeline.settle(time))
    let punch = CGFloat(1 + Self.punchGrow * TVSplashTimeline.punch(time))
    let unit = (Self.traceSize + (Self.finalSize - Self.traceSize) * settle) / TVSplashGeometry.markViewport * punch
    let markCenter = CGPoint(x: center.x + (finalCenter.x - center.x) * settle, y: center.y)
    let burst = TVSplashTimeline.burstAmount(time)
    let progress = TVSplashTimeline.traceProgress(time)
    let appear = TVSplashTimeline.cursorAppear(time)

    var markContext = context
    markContext.translateBy(x: markCenter.x - TVSplashGeometry.markPivot.x * unit, y: markCenter.y - TVSplashGeometry.markPivot.y * unit)
    markContext.scaleBy(x: unit, y: unit)
    var main = markContext
    main.opacity = 1 - 0.85 * burst
    mark.draw(in: main, progress: progress, appear: appear, color: TVPalette.accent)
    if burst > 0 {
      for (color, dx, dy, grow) in Self.prism {
        var ghost = markContext
        ghost.blendMode = .plusLighter
        ghost.opacity = burst
        let scale = 1 + grow * CGFloat(burst)
        let pivot = TVSplashGeometry.markPivot
        ghost.translateBy(x: dx * CGFloat(burst) + pivot.x, y: dy * CGFloat(burst) + pivot.y)
        ghost.scaleBy(x: scale, y: scale)
        ghost.translateBy(x: -pivot.x, y: -pivot.y)
        mark.draw(in: ghost, progress: progress, appear: appear, color: color)
      }
    }
    var wordContext = context
    wordContext.translateBy(x: finalCenter.x + Self.finalSize / 2 + Self.wordGap, y: center.y - Self.wordCap / 2)
    wordContext.scaleBy(x: letterUnit, y: letterUnit)
    wordmark.draw(in: wordContext, time: time, color: TVPalette.textHigh, pen: TVPalette.accent)
  }
}
