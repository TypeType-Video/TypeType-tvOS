import SwiftUI

struct TVDeviceLoginPanel: View {
  let state: LiveDeviceLoginViewModel.State

  private static let qrSize: CGFloat = 464

  var body: some View {
    HStack(alignment: .center, spacing: 56) {
      if case let .showing(_, link, _) = state {
        TVQRCode(text: link.absoluteString, size: Self.qrSize)
          .accessibilityLabel(Text("QR code to sign in to this TV from your phone"))
      } else {
        RoundedRectangle(cornerRadius: TVDimens.panelRadius)
          .fill(TVPalette.surfaceRaised)
          .frame(width: Self.qrSize, height: Self.qrSize)
          .accessibilityHidden(true)
      }
      VStack(alignment: .leading, spacing: 20) {
        Text("Scan with your phone's camera")
          .font(TVType.title)
          .foregroundStyle(TVPalette.textHigh)
        details
        if let status {
          Text(status.text)
            .font(TVType.body)
            .foregroundStyle(status.color)
            .lineLimit(2)
        }
      }
    }
  }

  @ViewBuilder
  private var details: some View {
    if case let .showing(userCode, link, _) = state {
      Text("Or open \(DeviceLoginLink.label(for: link)) on your phone and enter")
        .font(TVType.body)
        .foregroundStyle(TVPalette.textMid)
        .lineLimit(3)
      Text(verbatim: userCode)
        .font(.system(size: 76, weight: .semibold, design: .monospaced))
        .tracking(8)
        .foregroundStyle(TVPalette.textHigh)
        .accessibilityLabel(Text("Code \(Self.spelled(userCode))"))
    } else {
      Text("Preparing a code…")
        .font(TVType.body)
        .foregroundStyle(TVPalette.textMid)
    }
  }

  private var status: (text: LocalizedStringKey, color: Color)? {
    switch state {
    case .refused:
      return ("Refused on the phone. Here is a new code.", TVPalette.accentSoft)
    case .showing(_, _, scanned: true):
      return ("Code scanned. Confirm on your phone.", TVPalette.success)
    default:
      return nil
    }
  }

  private static func spelled(_ code: String) -> String {
    code.filter { $0.isLetter || $0.isNumber }.map(String.init).joined(separator: " ")
  }
}
