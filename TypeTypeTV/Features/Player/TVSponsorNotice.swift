import SwiftUI

struct TVSponsorNotice: View {
  @ObservedObject var controller: LivePlayerController

  var body: some View {
    if let notice = controller.sponsorBlockNotice, !notice.muted {
      let kind = LiveSponsorBlockPolicy.title(for: notice.category)
      HStack(spacing: 16) {
        Image(systemName: "forward.end.fill").foregroundStyle(TVPalette.accentSoft)
        Text("\(kind) skipped").font(TVType.title).foregroundStyle(TVPalette.textHigh).lineLimit(1)
        Label("Back to watch it", systemImage: "chevron.left")
          .font(TVType.meta).foregroundStyle(TVPalette.textHigh)
          .padding(.horizontal, 14).padding(.vertical, 6)
          .background(TVPalette.textHigh.opacity(0.14), in: Capsule())
      }
      .padding(.horizontal, 24).padding(.vertical, 14)
      .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 16))
      .padding(.leading, TVDimens.safeStart).padding(.bottom, 80)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
      .transition(.move(edge: .bottom).combined(with: .opacity))
      .accessibilityElement()
      .accessibilityLabel(Text("\(kind) skipped. Press left to watch it."))
      .task(id: notice.id) {
        try? await Task.sleep(for: .seconds(5))
        if controller.sponsorBlockNotice?.id == notice.id { controller.sponsorBlockNotice = nil }
      }
    }
  }
}
