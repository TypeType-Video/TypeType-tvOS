import SwiftUI

struct TVPillButtonStyle: ButtonStyle {
  var emphasized = false

  func makeBody(configuration: Configuration) -> some View {
    TVPillLabel(configuration: configuration, emphasized: emphasized)
  }
}

private struct TVPillLabel: View {
  let configuration: ButtonStyleConfiguration
  let emphasized: Bool
  @Environment(\.isFocused) private var isFocused

  var body: some View {
    configuration.label
      .font(TVType.button)
      .lineLimit(1)
      .foregroundStyle(isFocused ? TVPalette.ink : TVPalette.textHigh)
      .padding(.horizontal, 36)
      .frame(minHeight: 80)
      .background(background, in: Capsule())
      .scaleEffect(isFocused ? TVDimens.focusScaleSmall : 1)
      .opacity(configuration.isPressed ? 0.8 : 1)
      .animation(.easeOut(duration: 0.16), value: isFocused)
  }

  private var background: Color {
    if isFocused { return TVPalette.textHigh }
    return emphasized ? TVPalette.glassStrong : TVPalette.glass
  }
}

extension ButtonStyle where Self == TVPillButtonStyle {
  static var tvPill: TVPillButtonStyle { TVPillButtonStyle() }
  static var tvPillEmphasized: TVPillButtonStyle { TVPillButtonStyle(emphasized: true) }
}
