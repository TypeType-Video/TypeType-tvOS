import SwiftUI

struct TVRailItemStyle: ButtonStyle {
  let selected: Bool
  var railFocused = false

  func makeBody(configuration: Configuration) -> some View {
    TVRailItemLabel(configuration: configuration, selected: selected, railFocused: railFocused)
  }
}

private struct TVRailItemLabel: View {
  let configuration: ButtonStyleConfiguration
  let selected: Bool
  let railFocused: Bool
  @Environment(\.isFocused) private var isFocused

  var body: some View {
    HStack(spacing: 24) {
      Capsule().fill(TVPalette.accent).frame(width: 6, height: 36)
        .opacity(selected && !railFocused ? 1 : 0)
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
  func tvRailItem<Value: Hashable>(_ value: Value, selection: Binding<Value>, focus: FocusState<Value?>.Binding) -> some View {
    buttonStyle(TVRailItemStyle(selected: selection.wrappedValue == value, railFocused: focus.wrappedValue != nil))
      .focused(focus, equals: value)
      .disabled(focus.wrappedValue == nil && selection.wrappedValue != value)
      .accessibilityAddTraits(selection.wrappedValue == value ? [.isSelected] : [])
  }
}
