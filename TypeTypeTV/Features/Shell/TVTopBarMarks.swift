import SwiftUI

// Android TV's TopNav has the logo on the left and the account on the right of the tabs. The tvOS tab bar has no
// place for them, so they sit level with it, above every tab.
struct TVTopBarMarks: View {
  let user: AuthUser?
  let hidden: Bool

  var body: some View {
    HStack {
      TVBrandLogo(markSize: 44)
      Spacer()
      TVAccountBadge(user: user)
    }
    .padding(.horizontal, TVDimens.safeStart)
    .frame(height: 64)
    .padding(.top, 56)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .ignoresSafeArea()
    .opacity(hidden ? 0 : 1)
    .animation(.easeOut(duration: 0.25), value: hidden)
    .allowsHitTesting(false)
  }
}

// tvOS slides its tab bar away once the content scrolls; the screens say when, so the logo and the account leave
// with it instead of staying over the rows.
private struct TVContentScrolledKey: EnvironmentKey {
  static let defaultValue: (Bool) -> Void = { _ in }
}

extension EnvironmentValues {
  var tvContentScrolled: (Bool) -> Void {
    get { self[TVContentScrolledKey.self] }
    set { self[TVContentScrolledKey.self] = newValue }
  }
}

private struct TVScrollReporter: ViewModifier {
  @Environment(\.tvContentScrolled) private var report

  func body(content: Content) -> some View {
    if #available(tvOS 18.0, *) {
      content
        .onScrollGeometryChange(for: Bool.self) { $0.contentOffset.y + $0.contentInsets.top > 40 } action: { _, scrolled in
          report(scrolled)
        }
        .onAppear { report(false) }
    } else {
      content
    }
  }
}

extension View {
  func tvReportsScroll() -> some View {
    modifier(TVScrollReporter())
  }
}

struct TVAccountBadge: View {
  let user: AuthUser?
  @AppStorage(TVDeviceSetting.animatedAvatarKey) private var animates = true
  @Environment(\.displayScale) private var displayScale
  @State private var frames: TVAvatarFrames?
  @State private var settled = true
  @State private var settle: Task<Void, Never>?

  var body: some View {
    ZStack {
      Circle().fill(Color(hex24: 0x7F1D1D))
      Text(verbatim: Self.initials(user?.publicUsername)).font(TVType.label).foregroundStyle(TVPalette.accentSoft)
      // An emoji avatar's address is an SVG, which UIKit cannot draw: the emoji itself is shown, as on iPhone.
      if let emoji {
        Circle().fill(TVPalette.surfaceRaised)
        Text(verbatim: emoji).font(.system(size: 36))
      } else if let frames, animates {
        TVAnimatedAvatar(frames: frames, playing: settled).clipShape(Circle())
      } else if let url = user?.avatarURL {
        // Without a placeholder the initials stay visible while the picture loads or when it fails.
        TVRemoteImage(url: url, placeholder: false).clipShape(Circle())
      }
    }
    .frame(width: 64, height: 64)
    .task(id: animates && emoji == nil ? user?.avatarURL : nil) {
      guard animates, emoji == nil, let url = user?.avatarURL else { return frames = nil }
      frames = await TVAvatarFrames.load(url, pixels: 64 * displayScale)
    }
    // Android TV's RemoteActivity: an animated picture redraws the screen on its own, so it waits while the
    // focus moves and plays again two seconds after the last move.
    .onReceive(NotificationCenter.default.publisher(for: UIFocusSystem.didUpdateNotification)) { _ in
      guard frames != nil, animates else { return }
      settled = false
      settle?.cancel()
      settle = Task {
        guard (try? await Task.sleep(for: .seconds(2))) != nil else { return }
        settled = true
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(user?.publicUsername.map { Text("Signed in as \($0)") } ?? Text("Signed in"))
  }

  private var emoji: String? {
    guard user?.avatarType?.lowercased() == "emoji", let code = user?.avatarCode else { return nil }
    return LiveAvatar.emoji(fromHexCode: code)
  }

  static func initials(_ name: String?) -> String {
    let words = (name ?? "").split(whereSeparator: \.isWhitespace)
    switch words.count {
    case 0: return "?"
    case 1: return String(words[0].prefix(2)).uppercased()
    default: return (String(words[0].prefix(1)) + String(words[1].prefix(1))).uppercased()
    }
  }
}
