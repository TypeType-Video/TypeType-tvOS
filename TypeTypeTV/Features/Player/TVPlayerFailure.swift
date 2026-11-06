import SwiftUI

struct TVPlayerFailure: View {
  let message: String
  let onRetry: () -> Void
  let onClose: () -> Void

  var body: some View {
    VStack(spacing: 32) {
      Text(verbatim: message).font(TVType.body).foregroundStyle(TVPalette.textHigh).multilineTextAlignment(.center)
        .frame(maxWidth: 1100)
      HStack(spacing: 24) {
        Button("Try again", action: onRetry).buttonStyle(.tvPillEmphasized)
        Button("Close", action: onClose).buttonStyle(.tvPill)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black.opacity(0.85))
  }
}
