import SwiftUI

// Android TV's SectionRail item: the chosen section on a light glass with an accent bar, the others as plain text,
// white when focused. 464 pt wide like the rail's 232 dp.
struct TVRailItemStyle: ButtonStyle {
  let selected: Bool
  /// True while any entry of the rail holds focus. Focus moves before the selection catches up (`onChange(of:)` runs an
  /// update later), so a per-entry `isFocused` check alone leaves the entry just left rendering as "selected, not
  /// focused" for one frame — and its bar animates away from there.
  let railFocused: Bool

  func makeBody(configuration: Configuration) -> some View {
    TVRailItemLabel(configuration: configuration, selected: selected, railFocused: railFocused)
  }
}

private struct TVRailItemLabel: View {
  let configuration: ButtonStyleConfiguration
  let selected: Bool
  let railFocused: Bool
  @Environment(\.isFocused) private var isFocused

  // The bar marks the open section only while the rail is idle: while switching, focus already shows the section, and
  // a bar on the entry that was just left reads as a red dot next to the previous tab.
  private var showsIndicator: Bool { selected && !railFocused }

  var body: some View {
    HStack(spacing: 24) {
      Capsule()
        .fill(TVPalette.accent)
        // Fixed frame: the bar fades in place instead of shrinking into a dot on the way out.
        .frame(width: 6, height: 36)
        .opacity(showsIndicator ? 1 : 0)
        .animation(.easeOut(duration: 0.16), value: showsIndicator)
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
    buttonStyle(TVRailItemStyle(
      selected: selection.wrappedValue == value,
      railFocused: focus.wrappedValue != nil
    ))
      .focused(focus, equals: value)
      .accessibilityAddTraits(selection.wrappedValue == value ? [.isSelected] : [])
  }
}
