import SwiftUI

struct LiveToastHost: View {
  @ObservedObject var center: LiveToastCenter
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    VStack {
      Spacer()
      if let toast = center.current {
        card(toast)
          .id(toast.id)
          .transition(.liveBanner(reduceMotion: reduceMotion))
      }
    }
    .padding(.horizontal, 16)
    .padding(.bottom, 96)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .animation(.smooth(duration: 0.3), value: center.current)
    .accessibilityHidden(true)
  }

  @ViewBuilder
  private func card(_ toast: LiveToast) -> some View {
    let content = HStack(spacing: 12) {
      Image(systemName: toast.systemImage)
        .font(.title3.weight(.semibold))
        .foregroundStyle(toast.tone == .failure ? Color.orange : Color.green)
      VStack(alignment: .leading, spacing: 2) {
        Text(toast.title)
          .font(.callout.weight(.semibold))
        if let detail = toast.detail {
          Text(detail)
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
      }
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 14)
    if #available(iOS 26.0, *) {
      content.glassEffect(.regular, in: .capsule)
    } else {
      content.background(.regularMaterial, in: Capsule())
    }
  }
}
