import SwiftUI

enum TVSplashGeometry {
  static let markPivot = CGPoint(x: 12, y: 11.8)
  static let markViewport: CGFloat = 24
  static let buttonRadius: CGFloat = 1
  static let lowerButton = CGPoint(x: 18.7, y: 15.6)
  static let upperButton = CGPoint(x: 18.7, y: 11.4)
  static let cap: CGFloat = 10
  static let letterStroke: CGFloat = 2.5
  static let letterGap: CGFloat = 3.4

  static let markStrokes: [Path] = [
    polyline([(8, 2.6), (12, 6.6), (16, 2.6)]),
    polyline([(16.2, 7.8), (16.2, 20.6)]),
    Path { path in
      path.move(to: CGPoint(x: 16.2, y: 21))
      path.addLine(to: CGPoint(x: 5, y: 21))
      arc(&path, CGRect(x: 3, y: 17, width: 4, height: 4), 90, 90)
      path.addLine(to: CGPoint(x: 3, y: 9.4))
      arc(&path, CGRect(x: 3, y: 7.4, width: 4, height: 4), 180, 90)
      path.addLine(to: CGPoint(x: 19, y: 7.4))
      arc(&path, CGRect(x: 17, y: 7.4, width: 4, height: 4), 270, 90)
      path.addLine(to: CGPoint(x: 21, y: 19))
      arc(&path, CGRect(x: 17, y: 17, width: 4, height: 4), 0, 90)
      path.addLine(to: CGPoint(x: 16.2, y: 21))
    },
  ]

  static let word = "TYPETYPE"

  static var wordWidth: CGFloat {
    word.enumerated().reduce(0) { $0 + letterWidth($1.element) + ($1.offset > 0 ? letterGap : 0) }
  }

  static func wordStrokes() -> [Path] {
    var x: CGFloat = 0
    var strokes: [Path] = []
    for (index, letter) in word.enumerated() {
      if index > 0 { x += letterGap }
      strokes += letterStrokes(letter).map { $0.applying(CGAffineTransform(translationX: x, y: 0)) }
      x += letterWidth(letter)
    }
    return strokes
  }

  private static func letterWidth(_ letter: Character) -> CGFloat {
    switch letter {
    case "P": 6.4
    case "E": 7
    default: 8
    }
  }

  private static func letterStrokes(_ letter: Character) -> [Path] {
    switch letter {
    case "T":
      return [polyline([(0, 0), (8, 0)]), polyline([(4, 0), (4, cap)])]
    case "Y":
      return [
        Path { path in
          path.move(to: .zero)
          path.addCurve(to: CGPoint(x: 4, y: 5.2), control1: CGPoint(x: 0, y: 3.6), control2: CGPoint(x: 1.6, y: 5.2))
          path.addCurve(to: CGPoint(x: 8, y: 0), control1: CGPoint(x: 6.4, y: 5.2), control2: CGPoint(x: 8, y: 3.6))
        },
        polyline([(4, 5.2), (4, cap)]),
      ]
    case "P":
      return [Path { path in
        path.move(to: CGPoint(x: 0, y: cap))
        path.addLine(to: .zero)
        path.addLine(to: CGPoint(x: 3.4, y: 0))
        arc(&path, CGRect(x: 0.4, y: 0, width: 6, height: 6), 270, 180)
        path.addLine(to: CGPoint(x: 0, y: 6))
      }]
    default:
      return [
        Path { path in
          path.move(to: CGPoint(x: 7, y: 0))
          path.addLine(to: CGPoint(x: 2.6, y: 0))
          arc(&path, CGRect(x: 0, y: 0, width: 5.2, height: 5.2), 270, -90)
          path.addLine(to: CGPoint(x: 0, y: 7.4))
          arc(&path, CGRect(x: 0, y: 4.8, width: 5.2, height: 5.2), 180, -90)
          path.addLine(to: CGPoint(x: 7, y: cap))
        },
        polyline([(0, 5), (5.4, 5)]),
      ]
    }
  }

  private static func polyline(_ points: [(CGFloat, CGFloat)]) -> Path {
    Path { path in path.addLines(points.map { CGPoint(x: $0.0, y: $0.1) }) }
  }

  private static func arc(_ path: inout Path, _ rect: CGRect, _ start: Double, _ sweep: Double) {
    path.addArc(
      center: CGPoint(x: rect.midX, y: rect.midY),
      radius: rect.width / 2,
      startAngle: .degrees(start),
      endAngle: .degrees(start + sweep),
      clockwise: sweep < 0
    )
  }

  static func length(of path: Path) -> CGFloat {
    var total: CGFloat = 0
    var last = point(on: path, at: 0)
    for step in 1...48 {
      let next = point(on: path, at: CGFloat(step) / 48)
      total += hypot(next.x - last.x, next.y - last.y)
      last = next
    }
    return total
  }

  static func point(on path: Path, at fraction: CGFloat) -> CGPoint {
    guard fraction > 0 else {
      var start = CGPoint.zero
      path.forEach { element in
        if case let .move(to) = element, start == .zero { start = to }
      }
      return start
    }
    return path.trimmedPath(from: 0, to: min(fraction, 1)).currentPoint ?? .zero
  }
}
