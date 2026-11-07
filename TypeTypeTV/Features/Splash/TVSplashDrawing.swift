import SwiftUI

struct TVSplashMark {
  private enum Move {
    case trace(stroke: Int, from: CGFloat, to: CGFloat)
    case jump(from: CGPoint, to: CGPoint, lift: CGFloat, becomesDot: Bool)
  }

  private let moves: [Move] = {
    var moves: [Move] = [.trace(stroke: 0, from: 0, to: 0.5), .trace(stroke: 0, from: 0.5, to: 1),
                         .jump(from: CGPoint(x: 16, y: 2.6), to: CGPoint(x: 16.2, y: 7.8), lift: 3, becomesDot: false),
                         .trace(stroke: 1, from: 0, to: 0.5), .trace(stroke: 1, from: 0.5, to: 1)]
    for piece in 0..<6 { moves.append(.trace(stroke: 2, from: CGFloat(piece) / 6, to: CGFloat(piece + 1) / 6)) }
    moves.append(.jump(from: CGPoint(x: 16.2, y: 21), to: TVSplashGeometry.lowerButton, lift: 2, becomesDot: true))
    moves.append(.jump(from: TVSplashGeometry.lowerButton, to: TVSplashGeometry.upperButton, lift: 2, becomesDot: true))
    return moves
  }()

  private static let line = StrokeStyle(lineWidth: 2.3, lineCap: .round, lineJoin: .round)

  func draw(in context: GraphicsContext, progress: Double, appear: Double, color: Color) {
    let step = min(Int(progress), moves.count)
    let fraction = CGFloat(progress - Double(step))
    var revealed: [CGFloat] = [0, 0, 0]
    for move in moves.prefix(step) { if case let .trace(stroke, _, to) = move { revealed[stroke] = to } }
    let current = step < moves.count ? moves[step] : nil
    if case let .trace(stroke, from, to)? = current { revealed[stroke] = from + (to - from) * fraction }
    for (index, shown) in revealed.enumerated() where shown > 0 {
      context.stroke(TVSplashGeometry.markStrokes[index].trimmedPath(from: 0, to: shown), with: .color(color), style: Self.line)
    }
    for move in moves.prefix(step) {
      if case let .jump(_, to, _, true) = move { context.fill(dot(at: to), with: .color(color)) }
    }
    if let current { drawCursor(in: context, move: current, fraction: fraction, progress: progress, appear: appear, color: color) }
  }

  private func drawCursor(in context: GraphicsContext, move: Move, fraction: CGFloat, progress: Double, appear: Double, color: Color) {
    let position: CGPoint
    var morph: CGFloat = 0
    switch move {
    case let .trace(stroke, from, to):
      position = TVSplashGeometry.point(on: TVSplashGeometry.markStrokes[stroke], at: from + (to - from) * fraction)
    case let .jump(from, to, lift, becomesDot):
      position = CGPoint(x: from.x + (to.x - from.x) * fraction,
                         y: from.y + (to.y - from.y) * fraction - lift * sin(.pi * fraction))
      if becomesDot { morph = fraction }
    }
    let side = (3.2 + (TVSplashGeometry.buttonRadius * 2 - 3.2) * morph) * CGFloat(appear)
    let corner = 0.6 + (side / 2 - 0.6) * morph
    var turned = context
    turned.translateBy(x: position.x, y: position.y)
    turned.rotate(by: .degrees(90 * progress * Double(1 - morph)))
    turned.fill(Path(roundedRect: CGRect(x: -side / 2, y: -side / 2, width: side, height: side), cornerRadius: corner),
                with: .color(color))
  }

  private func dot(at point: CGPoint) -> Path {
    let radius = TVSplashGeometry.buttonRadius
    return Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
  }
}

struct TVSplashWordmark {
  private struct Piece {
    let path: Path?
    let from: CGPoint
    let to: CGPoint
    let length: CGFloat
  }

  private let pieces: [Piece]
  private let total: CGFloat
  let cursorAt: CGPoint

  private static let glideWeight: CGFloat = 0.45
  private static let line = StrokeStyle(lineWidth: TVSplashGeometry.letterStroke, lineCap: .round, lineJoin: .round)

  init() {
    let strokes = TVSplashGeometry.wordStrokes()
    cursorAt = CGPoint(x: TVSplashGeometry.wordWidth + TVSplashGeometry.letterGap, y: TVSplashGeometry.cap / 2)
    var pieces: [Piece] = []
    for (index, stroke) in strokes.enumerated() {
      let start = TVSplashGeometry.point(on: stroke, at: 0)
      if index > 0, let previous = pieces.last { pieces.append(Self.glide(previous.to, start)) }
      pieces.append(Piece(path: stroke, from: start, to: TVSplashGeometry.point(on: stroke, at: 1),
                          length: TVSplashGeometry.length(of: stroke)))
    }
    if let last = pieces.last { pieces.append(Self.glide(last.to, cursorAt)) }
    self.pieces = pieces
    total = pieces.reduce(0) { $0 + $1.length }
  }

  private static func glide(_ from: CGPoint, _ to: CGPoint) -> Piece {
    Piece(path: nil, from: from, to: to, length: hypot(to.x - from.x, to.y - from.y) * glideWeight)
  }

  func draw(in context: GraphicsContext, time: Double, color: Color, pen: Color) {
    let written = CGFloat(TVSplashTimeline.writeProgress(time))
    guard written > 0 else { return }
    var left = written * total
    var penAt = cursorAt
    for piece in pieces {
      let part = min(max(left, 0), piece.length)
      if let path = piece.path, part > 0 {
        context.stroke(path.trimmedPath(from: 0, to: part / piece.length), with: .color(color), style: Self.line)
        if part < piece.length { penAt = TVSplashGeometry.point(on: path, at: part / piece.length) }
      } else if piece.path == nil, part > 0, part < piece.length {
        let t = part / piece.length
        penAt = CGPoint(x: piece.from.x + (piece.to.x - piece.from.x) * t, y: piece.from.y + (piece.to.y - piece.from.y) * t)
      }
      left -= piece.length
      if left <= 0 { break }
    }
    if written < 1 {
      context.fill(Path(ellipseIn: CGRect(x: penAt.x - 1.5, y: penAt.y - 1.5, width: 3, height: 3)), with: .color(pen))
    } else if TVSplashTimeline.textCursorShown(time) {
      var bar = Path()
      bar.move(to: CGPoint(x: cursorAt.x, y: cursorAt.y - TVSplashGeometry.cap / 2 - 1.6))
      bar.addLine(to: CGPoint(x: cursorAt.x, y: cursorAt.y + TVSplashGeometry.cap / 2 + 1.6))
      context.stroke(bar, with: .color(pen), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
    }
  }
}
