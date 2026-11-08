import SwiftUI

struct TVShellJournal: ViewModifier {
  let tab: TVTab
  let depths: [Int]
  let playing: String?
  let menu: String?

  func body(content: Content) -> some View {
    content
      .onChange(of: tab) { old, new in TVJournal.note("tabs", "selected \(old) -> \(new)") }
      .onChange(of: depths) { _, depths in TVJournal.note("navigation", "stack depths \(depths)") }
      .onChange(of: playing) { _, id in TVJournal.note("player", id.map { "opened \($0)" } ?? "closed") }
      .onChange(of: menu) { _, id in TVJournal.note("menu", id == nil ? "video menu closed" : "video menu opened") }
  }
}
