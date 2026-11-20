import SwiftUI

struct TVSettingsSearchResults: View {
  let query: String
  let onOpen: (TVSettingsSearchEntry) -> Void

  var body: some View {
    let results = TVSettingsSearchIndex.search(query)
    Text("Results").textCase(.uppercase).font(TVType.label).tracking(3.6).foregroundStyle(TVPalette.textMid)
    if results.isEmpty {
      Text("No setting matches this search.").font(TVType.body).foregroundStyle(TVPalette.textMid)
    }
    ForEach(results) { entry in
      TVSettingRow(systemImage: entry.icon, title: Text(verbatim: entry.title), summary: entry.group.title) {
        onOpen(entry)
      }
    }
  }
}
