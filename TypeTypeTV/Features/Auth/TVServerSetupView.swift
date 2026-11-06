import SwiftUI

struct TVServerSetupView: View {
  @ObservedObject var coordinator: RootCoordinator
  @StateObject private var model = ServerSetupViewModel()
  @FocusState private var addressFocused: Bool
  @Environment(\.isEnabled) private var isEnabled

  var body: some View {
    TVAuthScaffold(
      title: String(localized: "Connect to your server"),
      subtitle: String(localized: "Enter the address of your TypeType instance.")
    ) {
      VStack(alignment: .leading, spacing: 28) {
        TextField(String(localized: "Instance address"), text: $model.url)
          .textContentType(.URL)
          .keyboardType(.URL)
          .autocorrectionDisabled()
          .textInputAutocapitalization(.never)
          .focused($addressFocused)
          .onSubmit(connect)
        if model.url.trimmingCharacters(in: .whitespaces).lowercased().hasPrefix("http://") {
          Text("HTTP does not encrypt your password or account data. Use it only on a trusted local network.")
            .font(TVType.meta)
            .foregroundStyle(TVPalette.accentSoft)
            .lineLimit(2)
        }
        Button(action: connect) {
          Label(model.isConnecting ? "Checking the server" : "Continue", systemImage: "arrow.right")
        }
        .buttonStyle(.tvPillEmphasized)
        .disabled(!model.canConnect)
        if let error = model.errorMessage {
          Text(error)
            .font(TVType.body)
            .foregroundStyle(TVPalette.accentSoft)
            .lineLimit(3)
        }
      }
    }
    .onAppear { addressFocused = isEnabled }
    // The screen appears under the startup intro, disabled: the field takes the focus once the intro is gone.
    .onChange(of: isEnabled) { _, enabled in if enabled { addressFocused = true } }
  }

  private func connect() {
    guard model.canConnect else { return }
    Task { await model.connect(using: coordinator) }
  }
}
