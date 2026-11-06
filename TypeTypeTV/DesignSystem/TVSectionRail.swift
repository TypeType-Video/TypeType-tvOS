import SwiftUI

// Android TV's SectionRail item: the chosen section on a light glass with an accent bar, the others as plain text,
// white when focused. 464 pt wide like the rail's 232 dp.
struct TVRailItemStyle: ButtonStyle {
  let selected: Bool

  func makeBody(configuration: Configuration) -> some View {
    TVRailItemLabel(configuration: configuration, selected: selected)
  }
}

private struct TVRailItemLabel: View {
  let configuration: ButtonStyleConfiguration
  let selected: Bool
  @Environment(\.isFocused) private var isFocused

  var body: some View {
    HStack(spacing: 24) {
      Capsule().fill(TVPalette.accent).frame(width: 6, height: selected && !isFocused ? 36 : 0)
      configuration.label.font(.system(size: 28, weight: .semibold)).lineLimit(1)
      Spacer(minLength: 0)
    }
    .foregroundStyle(isFocused ? TVPalette.ink : selected ? TVPalette.textHigh : TVPalette.textMid)
    .padding(.horizontal, 28)
    .padding(.vertical, 20)
    .frame(width: 464, alignment: .leading)
    .background(isFocused ? TVPalette.textHigh : selected ? TVPalette.glass : .clear,
                in: RoundedRectangle(cornerRadius: TVDimens.panelRadius))
    .scaleEffect(isFocused ? 1.03 : 1)
    .animation(.easeOut(duration: 0.16), value: isFocused)
    .animation(.easeOut(duration: 0.2), value: selected)
  }
}

extension View {
  // Rail entries follow the focus like Android's: the section opens as soon as its entry is focused.
  func tvRailItem<Value: Hashable>(_ value: Value, selection: Binding<Value>, focus: FocusState<Value?>.Binding) -> some View {
    buttonStyle(TVRailItemStyle(selected: selection.wrappedValue == value))
      .focused(focus, equals: value)
      .accessibilityAddTraits(selection.wrappedValue == value ? [.isSelected] : [])
  }
}
