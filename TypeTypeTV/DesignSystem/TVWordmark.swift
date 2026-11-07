import SwiftUI

struct TVWordmark: View {
  let capHeight: CGFloat
  var color = TVPalette.textHigh

  private static let strokes = TVSplashGeometry.wordStrokes()
  private static let line = StrokeStyle(lineWidth: TVSplashGeometry.letterStroke, lineCap: .round, lineJoin: .round)

  var body: some View {
    let unit = capHeight / TVSplashGeometry.cap
    let margin = TVSplashGeometry.letterStroke / 2
    Canvas { context, _ in
      context.scaleBy(x: unit, y: unit)
      context.translateBy(x: margin, y: margin)
      for stroke in Self.strokes { context.stroke(stroke, with: .color(color), style: Self.line) }
    }
    .frame(
      width: unit * (TVSplashGeometry.wordWidth + TVSplashGeometry.letterStroke),
      height: unit * (TVSplashGeometry.cap + TVSplashGeometry.letterStroke)
    )
    .accessibilityHidden(true)
  }
}
