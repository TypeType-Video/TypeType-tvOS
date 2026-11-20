import CoreImage.CIFilterBuiltins
import SwiftUI

struct TVLinkedAccountRows: View {
  @StateObject private var model: LiveLinkedAccountsViewModel

  init(youtube: LiveYouTubeSessionServiceProtocol, service: LiveLinkedAccountsServiceProtocol) {
    _model = StateObject(wrappedValue: LiveLinkedAccountsViewModel(youtube: youtube, service: service))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      youtube
      biliBili
    }
    .task { await model.refresh() }
    .onDisappear { model.stop() }
  }

  @ViewBuilder
  private var youtube: some View {
    TVSettingRow(systemImage: "play.rectangle", title: "YouTube", trailing: .value(status(model.youtubeConnected)))
    if let login = model.youtubeLogin {
      HStack(alignment: .center, spacing: 40) {
        VStack(alignment: .leading, spacing: 10) {
          Text("Enter this code on YouTube:").font(TVType.meta).foregroundStyle(TVPalette.textMid)
          Text(verbatim: login.userCode).font(.system(size: 64, weight: .bold, design: .monospaced))
            .foregroundStyle(TVPalette.textHigh)
          Text(verbatim: login.verificationURL).font(TVType.meta).foregroundStyle(TVPalette.textMid)
        }
        if let image = Self.qrImage(login.verificationURL) {
          qr(image, label: "YouTube sign-in page")
        }
      }
      .padding(.vertical, 12)
      TVSettingRow(systemImage: "xmark", title: "Cancel") { model.cancelYouTube() }
    } else if model.youtubeConnected == true {
      TVSettingRow(systemImage: "rectangle.portrait.and.arrow.right", title: "Disconnect YouTube") {
        Task { await model.disconnectYouTube() }
      }
    } else {
      TVSettingRow(systemImage: "number", title: "Connect YouTube with a code",
                   summary: "For videos that need a signed-in YouTube session. A secondary account is recommended.") {
        model.startYouTube()
      }
    }
    failure(model.youtubeError)
  }

  @ViewBuilder
  private var biliBili: some View {
    TVSettingRow(systemImage: "tv", title: "BiliBili",
                 trailing: .value(status(model.biliBiliState.map { $0 == .connected })))
    if let login = model.biliBiliQR {
      HStack(alignment: .center, spacing: 40) {
        if let image = Self.qrImage(login.qrURL) {
          qr(image, label: "BiliBili sign-in QR code")
        }
        (model.biliBiliScanned ? Text("Scanned. Confirm in the BiliBili app.") : Text("Scan this code with the BiliBili app."))
          .font(TVType.meta).foregroundStyle(TVPalette.textMid)
      }
      .padding(.vertical, 12)
      TVSettingRow(systemImage: "xmark", title: "Cancel") { model.cancelBiliBili() }
    } else if model.biliBiliState == .connected {
      TVSettingRow(systemImage: "rectangle.portrait.and.arrow.right", title: "Disconnect BiliBili") {
        Task { await model.disconnectBiliBili() }
      }
    } else {
      TVSettingRow(systemImage: "qrcode", title: "Connect BiliBili with a QR code",
                   summary: "For BiliBili videos in higher quality or that need an account.") {
        model.startBiliBili()
      }
    }
    failure(model.biliBiliError)
  }

  @ViewBuilder
  private func failure(_ text: String?) -> some View {
    if let text {
      Text(verbatim: text).font(TVType.meta).foregroundStyle(TVPalette.accentSoft)
    }
  }

  private func qr(_ image: UIImage, label: LocalizedStringKey) -> some View {
    Image(uiImage: image)
      .interpolation(.none)
      .resizable()
      .frame(width: 260, height: 260)
      .padding(16)
      .background(.white, in: RoundedRectangle(cornerRadius: 16))
      .accessibilityLabel(label)
  }

  private func status(_ connected: Bool?) -> String {
    switch connected {
    case nil: "…"
    case .some(true): String(localized: "Connected")
    case .some(false): String(localized: "Not connected")
    }
  }

  static func qrImage(_ text: String) -> UIImage? {
    let filter = CIFilter.qrCodeGenerator()
    filter.message = Data(text.utf8)
    filter.correctionLevel = "M"
    guard let output = filter.outputImage,
      let image = CIContext().createCGImage(output, from: output.extent)
    else { return nil }
    return UIImage(cgImage: image)
  }
}
