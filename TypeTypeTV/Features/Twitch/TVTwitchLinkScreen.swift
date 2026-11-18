import SwiftUI

struct TVTwitchLinkScreen: View {
  @StateObject private var model: LiveTwitchLinkViewModel
  @FocusState private var focused: Bool

  private static let qrSize: CGFloat = 420

  init(service: LiveTwitchAccountServiceProtocol) {
    _model = StateObject(wrappedValue: LiveTwitchLinkViewModel(service: service))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 40) {
      Text("Twitch").font(TVType.display).foregroundStyle(TVPalette.textHigh)
      Text("To chat, vote in polls and follow channels with your Twitch account.")
        .font(TVType.body).foregroundStyle(TVPalette.textMid)
      content
      if let error = model.error {
        Text(verbatim: error).font(TVType.body).foregroundStyle(TVPalette.accentSoft)
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, TVDimens.safeStart)
    .padding(.top, 60)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .task { await model.refresh() }
    .onDisappear { model.cancel() }
  }

  @ViewBuilder
  private var content: some View {
    if model.isLinked {
      Text("Linked to \(model.status?.name ?? "")").font(TVType.title).foregroundStyle(TVPalette.textHigh)
      Button("Unlink") { Task { await model.unlink() } }
        .buttonStyle(.tvPill)
        .disabled(model.isBusy)
        .focused($focused)
        .onAppear { focused = true }
    } else if let device = model.device {
      HStack(alignment: .center, spacing: 56) {
        TVQRCode(text: device.verificationURI, size: Self.qrSize)
          .accessibilityLabel(Text("QR code to open twitch.tv/activate on your phone"))
        VStack(alignment: .leading, spacing: 20) {
          Text("Enter this code on twitch.tv/activate:").font(TVType.body).foregroundStyle(TVPalette.textMid)
          Text(verbatim: device.userCode)
            .font(.system(size: 76, weight: .semibold, design: .monospaced))
            .tracking(8)
            .foregroundStyle(TVPalette.textHigh)
          Button("Cancel") { model.cancel() }
            .buttonStyle(.tvPill)
            .focused($focused)
            .onAppear { focused = true }
        }
      }
    } else if model.status != nil || model.error != nil {
      Button("Link a Twitch account") { model.start() }
        .buttonStyle(.tvPill)
        .focused($focused)
        .onAppear { focused = true }
        .accessibilityIdentifier("tv.twitch.link")
    } else {
      ProgressView()
    }
  }
}
