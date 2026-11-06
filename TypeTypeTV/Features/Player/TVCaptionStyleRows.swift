import SwiftUI

// Android TV's CaptionStylePanel: each row moves its choice one step, and the sample shows the result at once.
struct TVCaptionStyleRows: View {
  @ObservedObject var controller: LivePlayerController
  @FocusState private var first: Bool

  var body: some View {
    let styles = controller.settings.captionStyles
    VStack(alignment: .leading, spacing: 14) {
      row("Size", "textformat.size", "\(styles.sizePercent)%") { controller.setCaptionStyles(styles.nextSize()) }
        .focused($first)
      row("Text color", "paintpalette", colorName(styles.foregroundColor)) { controller.setCaptionStyles(styles.nextColor()) }
      row("Background", "square.stack", backgroundName(styles.backgroundOpacityPercent)) {
        controller.setCaptionStyles(styles.nextBackground())
      }
      TVCaptionText(text: String(localized: "Sample subtitle"), styles: styles)
        .frame(width: 560, height: 200)
        .background(Color(hex24: 0x30343B), in: RoundedRectangle(cornerRadius: TVDimens.panelRadius))
        .padding(.top, 12)
        .accessibilityHidden(true)
    }
    .onAppear { Task { first = true } }
  }

  private func row(_ title: LocalizedStringKey, _ icon: String, _ value: String, perform: @escaping () -> Void) -> some View {
    Button(action: perform) {
      HStack(spacing: 20) {
        Image(systemName: icon).frame(width: 40)
        Text(title)
        Spacer()
        Text(verbatim: value).opacity(0.7)
      }
      .frame(width: 560, alignment: .leading)
    }
    .buttonStyle(.tvPill)
  }

  private func colorName(_ hex: String) -> String {
    switch hex.lowercased() {
    case "#ffeb3b": String(localized: "Yellow")
    case "#00e5ff": String(localized: "Cyan")
    case "#69f0ae": String(localized: "Green")
    default: String(localized: "White")
    }
  }

  private func backgroundName(_ percent: Int) -> String {
    switch percent {
    case ..<25: String(localized: "None")
    case ..<75: String(localized: "Translucent")
    default: String(localized: "Solid")
    }
  }
}
