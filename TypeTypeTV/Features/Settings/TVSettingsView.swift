import SwiftUI

struct TVSettingsView: View {
  @ObservedObject var coordinator: RootCoordinator

  var body: some View {
    HStack(alignment: .top, spacing: 80) {
      VStack(alignment: .leading, spacing: 40) {
        Text("Settings")
          .font(TVType.headline)
          .foregroundStyle(TVPalette.textHigh)
        row(title: "Server", value: serverLabel)
        row(title: "Account", value: accountLabel)
        HStack(spacing: 24) {
          Button {
            coordinator.showServerSetup()
          } label: {
            Label("Change instance", systemImage: "arrow.left.arrow.right")
          }
          .buttonStyle(.tvPill)
          Button {
            Task { await coordinator.signOut() }
          } label: {
            Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
          }
          .buttonStyle(.tvPill)
        }
        .padding(.top, 20)
      }
      .frame(maxWidth: 1100, alignment: .leading)
      Spacer()
    }
    .padding(.horizontal, TVDimens.safeStart)
    .padding(.top, 60)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(TVPalette.ink.ignoresSafeArea())
  }

  private func row(title: LocalizedStringKey, value: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(TVType.label)
        .tracking(1.8)
        .foregroundStyle(TVPalette.textLow)
      Text(verbatim: value)
        .font(TVType.title)
        .foregroundStyle(TVPalette.textHigh)
    }
    .accessibilityElement(children: .combine)
  }

  private var serverLabel: String {
    guard let server = coordinator.selectedServer else { return "" }
    let host = server.baseURL?.host ?? server.baseURLString
    return server.name == host ? host : "\(server.name) · \(host)"
  }

  private var accountLabel: String {
    guard let user = coordinator.currentUser else { return "" }
    return user.publicUsername ?? user.role.title
  }
}
