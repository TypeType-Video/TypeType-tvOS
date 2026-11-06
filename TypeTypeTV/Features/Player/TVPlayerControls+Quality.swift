import Foundation

extension LivePlayerController {
  var currentHeight: Int? {
    let sources = availableVideoSources
    if let selected = selectedVideoSourceID, let source = sources.first(where: { $0.selectionID == selected }) {
      return source.effectiveHeight
    }
    return sources.map(\.effectiveHeight).max()
  }

  var qualityLabel: String {
    guard selectedVideoSourceID != nil, let height = currentHeight else { return String(localized: "Auto") }
    return "\(height)p"
  }
}
