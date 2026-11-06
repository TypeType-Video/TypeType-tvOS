import SwiftUI
import UIKit

struct TVLoginView: View {
  @ObservedObject var coordinator: RootCoordinator
  @StateObject private var auth = LiveAuthViewModel()
  @State private var usePassword = false
  @State private var qrUnavailable = false
  @State private var deviceError: String?

  private var showsQR: Bool {
    !usePassword && !qrUnavailable && deviceLoginInputs != nil
  }

  var body: some View {
    TVAuthScaffold(title: title, subtitle: subtitle, width: showsQR ? 1440 : 1200) {
      VStack(alignment: .leading, spacing: 32) {
        if showsQR, let inputs = deviceLoginInputs {
          TVDeviceLoginSection(
            service: inputs.service,
            apiBase: inputs.apiBase,
            onApproved: signIn,
            onUnavailable: { qrUnavailable = true }
          )
        } else {
          TVPasswordLoginForm(model: auth, onSubmit: submit)
        }
        actions
        if let message = deviceError ?? auth.errorMessage {
          Text(message)
            .font(TVType.body)
            .foregroundStyle(TVPalette.accentSoft)
            .lineLimit(3)
        }
      }
    }
    .task { await auth.load(using: coordinator) }
  }

  private var actions: some View {
    HStack(spacing: 20) {
      if !qrUnavailable, deviceLoginInputs != nil {
        Button {
          usePassword.toggle()
          deviceError = nil
          auth.clearError()
        } label: {
          Label(showsQR ? "Use a password" : "Use a QR code", systemImage: showsQR ? "key" : "qrcode")
        }
        .buttonStyle(showsQR ? .tvPillEmphasized : .tvPill)
      }
      if coordinator.instance?.guestAllowed == true {
        Button("Continue as guest") {
          Task { await auth.continueAsGuest(using: coordinator) }
        }
        .buttonStyle(.tvPill)
      }
      Button {
        coordinator.showServerSetup()
      } label: {
        Label("Change instance", systemImage: "arrow.left.arrow.right")
      }
      .buttonStyle(.tvPill)
    }
  }

  private var title: String {
    let name = coordinator.instance?.name.trimmingCharacters(in: .whitespaces) ?? ""
    let server = name.isEmpty ? (coordinator.selectedServer?.baseURL?.host ?? "") : name
    return String(localized: "Sign in to \(server)")
  }

  private var subtitle: String {
    if showsQR { return String(localized: "No typing: scan the code and confirm on your phone.") }
    if auth.mode == .register { return String(localized: "Create your account on this server.") }
    return String(localized: "Use your account, or continue as a guest.")
  }

  private var deviceLoginInputs: (service: LiveDeviceLoginServiceProtocol, apiBase: URL)? {
    guard let service = coordinator.dependencies.deviceLoginService,
      let base = coordinator.selectedServer?.baseURL
    else { return nil }
    return (service, base)
  }

  private func submit() {
    Task { await auth.submit(using: coordinator) }
  }

  private func signIn(_ accessToken: String) {
    Task {
      do {
        try await coordinator.signInWithDevice(accessToken: accessToken)
      } catch {
        deviceError = error.localizedDescription
      }
    }
  }
}

private struct TVDeviceLoginSection: View {
  @StateObject private var model: LiveDeviceLoginViewModel
  let onApproved: (String) -> Void
  let onUnavailable: () -> Void

  init(
    service: LiveDeviceLoginServiceProtocol,
    apiBase: URL,
    onApproved: @escaping (String) -> Void,
    onUnavailable: @escaping () -> Void
  ) {
    _model = StateObject(
      wrappedValue: LiveDeviceLoginViewModel(
        service: service,
        apiBase: apiBase,
        deviceName: String(localized: "TypeType TV · \(UIDevice.current.name)")
      )
    )
    self.onApproved = onApproved
    self.onUnavailable = onUnavailable
  }

  var body: some View {
    TVDeviceLoginPanel(state: model.state)
      .task { await model.run() }
      .onChange(of: model.state) { _, state in
        switch state {
        case let .approved(accessToken): onApproved(accessToken)
        case .unavailable: onUnavailable()
        default: break
        }
      }
  }
}
