import SwiftUI

struct TVHomeSkeleton: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      block(176, 20)
      block(720, 72).padding(.top, 28)
      block(500, 72).padding(.top, 16)
      block(860, 24).padding(.top, 32)
      block(780, 24).padding(.top, 16)
      HStack(spacing: 24) {
        block(224, 80, radius: 40)
        block(264, 80, radius: 40)
      }
      .padding(.top, 48)
      block(300, 20).padding(.top, 68)
      HStack(spacing: 40) {
        ForEach(0..<5, id: \.self) { _ in
          VStack(alignment: .leading, spacing: 0) {
            block(392, 220, radius: TVDimens.cardRadius)
            block(300, 24).padding(.top, 20)
            block(200, 20).padding(.top, 12)
          }
        }
      }
      .frame(width: 1808, alignment: .leading)
      .padding(.top, 28)
    }
    .padding(.leading, TVDimens.safeStart)
    .padding(.top, 168)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .accessibilityElement()
    .accessibilityLabel(Text("Loading"))
  }

  private func block(_ width: CGFloat, _ height: CGFloat, radius: CGFloat? = nil) -> some View {
    RoundedRectangle(cornerRadius: radius ?? height / 2).fill(TVPalette.surfaceRaised).frame(width: width, height: height)
  }
}
