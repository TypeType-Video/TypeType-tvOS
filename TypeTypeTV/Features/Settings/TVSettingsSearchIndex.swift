import Foundation

struct TVSettingsSearchEntry: Identifiable, Hashable {
  let group: TVSettingsGroup
  let icon: String
  let title: String
  let english: String

  var id: String { "\(group.rawValue)|\(icon)|\(english)" }
}

enum TVSettingsSearchIndex {
  private static let rows: [(TVSettingsGroup, String, String)] = [
    (.playback, "speedometer", "Playback speed"),
    (.playback, "forward.end.alt", "Autoplay next video"),
    (.playback, "captions.bubble", "Show captions by default"),
    (.playback, "forward", "Sponsor segments"),
    (.playback, "tv", "Seekbar icon"),
    (.playback, "clock.arrow.circlepath", "Save watch history"),
    (.playback, "rectangle.righthalf.inset.filled", "Chat position"),
    (.playback, "textformat.size", "Chat text size"),
    (.content, "house", "Start on"),
    (.content, "arrow.uturn.down", "Back from the top bar"),
    (.content, "magnifyingglass", "Search service"),
    (.content, "play.circle", "Continue watching"),
    (.content, "sparkles.tv", "Recommendations"),
    (.content, "rectangle.stack", "More videos"),
    (.content, "rectangle.inset.bottomtrailing.filled", "End screens"),
    (.content, "text.bubble", "Comments"),
    (.content, "rectangle.portrait", "Shorts"),
    (.content, "person.badge.key", "Members-only videos"),
    (.content, "slider.horizontal.3", "Home page by algorithm"),
    (.blocked, "nosign", "Blocked channels"),
    (.performance, "play.rectangle", "Video previews"),
    (.performance, "person.crop.circle.badge.clock", "Animated profile picture"),
    (.performance, "photo", "Background picture"),
    (.performance, "sparkles", "Startup intro"),
    (.account, "rectangle.portrait.and.arrow.right", "Sign out"),
    (.account, "checkmark.circle", "Mark all as read"),
    (.linked, "link", "Linked accounts"),
    (.instance, "arrow.left.arrow.right", "Change instance"),
    (.instance, "number", "Server version"),
    (.journal, "doc.text.magnifyingglass", "Journal"),
    (.about, "info.circle", "About"),
  ]

  static let entries: [TVSettingsSearchEntry] = rows.map { group, icon, english in
    TVSettingsSearchEntry(group: group, icon: icon, title: String(localized: String.LocalizationValue(english)), english: english)
  }

  static func search(_ query: String) -> [TVSettingsSearchEntry] {
    let needle = fold(query)
    guard !needle.isEmpty else { return [] }
    return entries
      .filter { fold($0.title).contains(needle) || fold($0.english).contains(needle) }
      .sorted { fold($0.title).hasPrefix(needle) && !fold($1.title).hasPrefix(needle) }
  }

  private static func fold(_ text: String) -> String {
    text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).trimmingCharacters(in: .whitespaces)
  }
}
