import SwiftUI

struct LiveToastHost: View {
  @ObservedObject var center: LiveToastCenter

  var body: some View {
    VStack {
      Spacer()
      if let toast = center.current {
        HStack(spacing: 16) {
          Image(systemName: toast.systemImage)
            .foregroundStyle(toast.tone == .failure ? Color.orange : Color.green)
          VStack(alignment: .leading, spacing: 4) {
            Text(toast.title)
              .font(.headline)
            if let detail = toast.detail {
              Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
          }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 20)
        .background(.regularMaterial, in: Capsule())
        .id(toast.id)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
      }
    }
    .padding(.bottom, 60)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .animation(.smooth(duration: 0.3), value: center.current)
    .accessibilityHidden(true)
  }
}
