import SwiftUI

// Android TV's SearchKeyboard: nine keys a row, then space, delete, clear and the voice key.
struct TVSearchKeyboard: View {
  @Binding var query: String
  var firstKey: FocusState<Bool>.Binding
  @State private var spoken = ""
  @FocusState private var voiceFocused: Bool

  private static let rows = stride(from: 0, to: LiveSearchInput.keys.count, by: LiveSearchInput.keysPerRow).map {
    Array(LiveSearchInput.keys[$0..<$0 + LiveSearchInput.keysPerRow])
  }

  var body: some View {
    VStack(spacing: 12) {
      ForEach(Self.rows.indices, id: \.self) { row in
        HStack(spacing: 12) {
          ForEach(Self.rows[row], id: \.self) { character in
            let key = Button { query = LiveSearchInput.append(query, character) } label: {
              Text(verbatim: character.uppercased()).font(.system(size: 34, weight: .medium))
            }
            .buttonStyle(TVKeyCapStyle())
            .accessibilityLabel(Text(verbatim: String(character)))
            if row == 0, character == Self.rows[0][0] { key.focused(firstKey) } else { key }
          }
        }
      }
      HStack(spacing: 12) {
        action("space", "Space") { query = LiveSearchInput.append(query, " ") }
        action("delete.left", "Delete") { query = LiveSearchInput.delete(query) }
        action("xmark", "Clear") { query = "" }
        voiceKey
      }
    }
  }

  private func action(_ systemImage: String, _ label: LocalizedStringKey, perform: @escaping () -> Void) -> some View {
    Button(action: perform) { Image(systemName: systemImage).font(.system(size: 30, weight: .medium)) }
      .buttonStyle(TVKeyCapStyle())
      .accessibilityLabel(Text(label))
  }

  // tvOS gives dictation only to its own keyboard: this key is a hidden text field, so selecting it opens the
  // system keyboard, where the remote's microphone types the words.
  private var voiceKey: some View {
    ZStack {
      TVKeyFace(focused: voiceFocused) { Image(systemName: "mic.fill").font(.system(size: 30, weight: .medium)) }
      TextField("", text: $spoken)
        .textFieldStyle(.plain)
        .foregroundStyle(.clear)
        .tint(.clear)
        .opacity(0.02)
        .focused($voiceFocused)
        .accessibilityLabel(Text("Voice search"))
    }
    .frame(maxWidth: .infinity)
    .frame(height: 96)
    .onChange(of: voiceFocused) { _, focused in if focused { spoken = query } }
    .onChange(of: spoken) { _, text in if voiceFocused { query = LiveSearchInput.normalized(text) } }
  }
}

struct TVKeyCapStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    TVKeyCapLabel(configuration: configuration)
  }
}

private struct TVKeyCapLabel: View {
  let configuration: ButtonStyleConfiguration
  @Environment(\.isFocused) private var isFocused

  var body: some View {
    TVKeyFace(focused: isFocused) { configuration.label }
      .frame(maxWidth: .infinity)
      .frame(height: 96)
  }
}

struct TVKeyFace<Content: View>: View {
  let focused: Bool
  @ViewBuilder let content: () -> Content

  var body: some View {
    content()
      .foregroundStyle(focused ? TVPalette.ink : TVPalette.textHigh)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(focused ? TVPalette.textHigh : TVPalette.surfaceRaised, in: RoundedRectangle(cornerRadius: 16))
      .scaleEffect(focused ? 1.1 : 1)
      .shadow(color: .black.opacity(focused ? 0.4 : 0), radius: 12, y: 6)
      .animation(.easeOut(duration: 0.12), value: focused)
  }
}
