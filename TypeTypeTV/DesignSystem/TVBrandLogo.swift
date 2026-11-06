import SwiftUI

struct TVBrandLogo: View {
  var markSize: CGFloat = 60

  var body: some View {
    HStack(spacing: markSize * 0.36) {
      Image("TypeTypeLogo")
        .resizable()
        .scaledToFit()
        .frame(width: markSize, height: markSize)
      TVWordmark(capHeight: markSize * 0.5)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(verbatim: "TypeType"))
  }
}

struct TVAuthScaffold<Content: View>: View {
  let title: String
  let subtitle: String
  var width: CGFloat = 1040
  @ViewBuilder let content: Content

  var body: some View {
    ZStack {
      TVPalette.ink.ignoresSafeArea()
      VStack(alignment: .leading, spacing: 48) {
        TVBrandLogo()
        VStack(alignment: .leading, spacing: 12) {
          Text(title)
            .font(TVType.headline)
            .foregroundStyle(TVPalette.textHigh)
            .lineLimit(2)
          Text(subtitle)
            .font(TVType.body)
            .foregroundStyle(TVPalette.textMid)
            .lineLimit(2)
          content
            .padding(.top, 28)
        }
        .padding(56)
        .frame(width: width, alignment: .leading)
        .background(TVPalette.surface.opacity(0.85), in: RoundedRectangle(cornerRadius: TVDimens.panelRadius))
      }
    }
  }
}
