import SwiftUI

enum TVDeviceSetting {
  static let introKey = "tv.performance.intro"
  static let backdropKey = "tv.performance.backdrop"
  static let videoPreviewsKey = "tv.performance.video-previews"
  static let animatedAvatarKey = "tv.performance.animated-avatar"
}

struct TVSettingRow: View {
  enum Trailing {
    case toggle(Bool)
    case value(String)
    case none
  }

  let systemImage: String
  let title: Text
  let summary: LocalizedStringKey?
  let trailing: Trailing
  let action: (() -> Void)?

  init(
    systemImage: String, title: LocalizedStringKey, summary: LocalizedStringKey? = nil, trailing: Trailing = .none,
    action: (() -> Void)? = nil
  ) {
    self.init(systemImage: systemImage, title: Text(title), summary: summary, trailing: trailing, action: action)
  }

  init(
    systemImage: String, title: Text, summary: LocalizedStringKey? = nil, trailing: Trailing = .none,
    action: (() -> Void)? = nil
  ) {
    self.systemImage = systemImage
    self.title = title
    self.summary = summary
    self.trailing = trailing
    self.action = action
  }

  var body: some View {
    Button { action?() } label: {
      HStack(spacing: 28) {
        Image(systemName: systemImage).font(.system(size: 26, weight: .medium))
          .frame(width: 64, height: 64).background(TVPalette.glass, in: Circle())
        VStack(alignment: .leading, spacing: 6) {
          title.font(TVType.title)
          if let summary { Text(summary).font(TVType.meta).opacity(0.7).lineLimit(2) }
        }
        Spacer(minLength: 20)
        switch trailing {
        case let .toggle(isOn):
          Capsule().fill(isOn ? TVPalette.accent : TVPalette.outline).frame(width: 84, height: 44)
            .overlay(alignment: isOn ? .trailing : .leading) { Circle().fill(.white).frame(width: 36).padding(4) }
            .accessibilityHidden(true)
        case let .value(text):
          HStack(spacing: 10) {
            Text(verbatim: text).font(TVType.meta)
            if action != nil { Image(systemName: "chevron.up.chevron.down").font(.system(size: 22)) }
          }
        case .none:
          EmptyView()
        }
      }
      .padding(.horizontal, 36)
      .padding(.vertical, 24)
      .frame(width: 1180, alignment: .leading)
    }
    .buttonStyle(TVSettingRowStyle())
    .disabled(action == nil)
    .accessibilityValue(accessibilityValue)
  }

  private var accessibilityValue: Text {
    switch trailing {
    case let .toggle(isOn): Text(isOn ? "On" : "Off")
    case let .value(text): Text(verbatim: text)
    case .none: Text(verbatim: "")
    }
  }
}

private struct TVSettingRowStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    TVSettingRowLabel(configuration: configuration)
  }
}

private struct TVSettingRowLabel: View {
  let configuration: ButtonStyleConfiguration
  @Environment(\.isFocused) private var isFocused

  var body: some View {
    configuration.label
      .foregroundStyle(isFocused ? TVPalette.ink : TVPalette.textHigh)
      .background(isFocused ? TVPalette.textHigh : TVPalette.surface, in: RoundedRectangle(cornerRadius: TVDimens.panelRadius))
      .scaleEffect(isFocused ? TVDimens.focusScaleSmall : 1)
      .animation(.easeOut(duration: 0.16), value: isFocused)
  }
}

struct TVChoice: Identifiable {
  let id: String
  let label: String
}

struct TVChoicePicker: View {
  let title: LocalizedStringKey
  let summary: LocalizedStringKey?
  let choices: [TVChoice]
  let selected: String
  let onPick: (String) -> Void
  let onClose: () -> Void
  @FocusState private var focused: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text(title).font(TVType.headline).foregroundStyle(TVPalette.textHigh)
      if let summary { Text(summary).font(TVType.meta).foregroundStyle(TVPalette.textMid) }
      ForEach(choices) { choice in
        Button {
          onPick(choice.id)
          onClose()
        } label: {
          HStack {
            Text(verbatim: choice.label)
            Spacer()
            if choice.id == selected { Image(systemName: "checkmark") }
          }
          .frame(width: 520, alignment: .leading)
        }
        .buttonStyle(.tvPill)
        .focused($focused, equals: choice.id)
      }
    }
    .padding(56)
    .background(TVPalette.surface, in: RoundedRectangle(cornerRadius: TVDimens.panelRadius))
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(TVPalette.ink.opacity(0.7).ignoresSafeArea())
    .focusSection()
    .onExitCommand(perform: onClose)
    .onAppear { focused = selected }
  }
}
