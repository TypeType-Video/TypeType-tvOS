import SwiftUI

// Android TV's TopNav has the logo on the left and the account on the right of the tabs. The tvOS tab bar has no
// place for them, so they sit level with it, above every tab.
struct TVTopBarMarks: View {
  let user: AuthUser?

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
    .allowsHitTesting(false)
  }
}

struct TVAccountBadge: View {
  let user: AuthUser?

  var body: some View {
    ZStack {
      Circle().fill(Color(hex24: 0x7F1D1D))
      Text(verbatim: Self.initials(user?.publicUsername)).font(TVType.label).foregroundStyle(TVPalette.accentSoft)
      if let url = user?.avatarURL { TVRemoteImage(url: url).clipShape(Circle()) }
    }
    .frame(width: 64, height: 64)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(user?.publicUsername.map { Text("Signed in as \($0)") } ?? Text("Signed in"))
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
