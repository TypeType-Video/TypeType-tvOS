import SwiftUI

struct TVBareButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
  }
}

struct TVCircleButton: View {
  let systemImage: String
  let label: LocalizedStringKey
  var emphasized = false
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: systemImage)
        .accessibilityLabel(Text(label))
    }
    .buttonStyle(TVCircleButtonStyle(emphasized: emphasized))
  }
}

struct TVRepeatingCircleButton: View {
  let systemImage: String
  let label: LocalizedStringKey
  let step: () -> Void
  @State private var holding: Task<Void, Never>?
  @FocusState private var focused: Bool

  var body: some View {
    Button {
      if holding != nil { stop() } else { step() }
    } label: {
      Image(systemName: systemImage)
        .accessibilityLabel(Text(label))
    }
    .buttonStyle(TVCircleButtonStyle())
    .focused($focused)
    .simultaneousGesture(LongPressGesture(minimumDuration: 0.4).onEnded { _ in start() })
    .onChange(of: focused) { _, focused in if !focused { stop() } }
    .onDisappear(perform: stop)
  }

  private func start() {
    holding?.cancel()
    holding = Task {
      repeat { step() } while (try? await Task.sleep(for: .milliseconds(280))) != nil
    }
  }

  private func stop() {
    holding?.cancel()
    holding = nil
  }
}

struct TVCircleButtonStyle: ButtonStyle {
  var emphasized = false

  func makeBody(configuration: Configuration) -> some View {
    TVCircleLabel(configuration: configuration, emphasized: emphasized)
  }
}

private struct TVCircleLabel: View {
  let configuration: ButtonStyleConfiguration
  let emphasized: Bool
  @Environment(\.isFocused) private var isFocused
  @Environment(\.isEnabled) private var isEnabled

  var body: some View {
    let size: CGFloat = emphasized ? 108 : 92
    configuration.label
      .font(.system(size: emphasized ? 40 : 34, weight: .semibold))
      .foregroundStyle(isFocused ? TVPalette.ink : TVPalette.textHigh)
      .frame(width: size, height: size)
      .background(isFocused ? TVPalette.textHigh : (emphasized ? TVPalette.glassStrong : TVPalette.glass), in: Circle())
      .scaleEffect(isFocused ? TVDimens.focusScaleSmall : 1)
      .opacity(isEnabled ? 1 : 0.4)
      .animation(.easeOut(duration: 0.16), value: isFocused)
  }
}

struct TVBadge: View {
  enum Tone {
    case service
    case plain
  }

  let text: String
  let tone: Tone

  var body: some View {
    Text(verbatim: text)
      .font(.system(size: 20, weight: .bold))
      .tracking(1.6)
      .padding(.horizontal, 12)
      .padding(.vertical, 4)
      .foregroundStyle(TVPalette.textHigh)
      .background(tone == .service ? TVPalette.accent : TVPalette.surfaceRaised, in: RoundedRectangle(cornerRadius: 6))
  }
}
