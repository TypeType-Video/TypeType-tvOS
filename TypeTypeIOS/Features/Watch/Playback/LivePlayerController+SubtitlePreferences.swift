import Foundation

extension LivePlayerController {
  func setSubtitlesEnabled(_ enabled: Bool) {
    subtitlesEnabled = enabled
    updateSettings { $0.subtitlesEnabled = enabled }
    if let item = player.currentItem {
      configureSubtitles(for: item)
    }
    reloadNativeSubtitles()
  }

  func selectSubtitleLanguage(_ language: String) {
    selectSubtitleLanguage(language, remembers: true)
  }

  // A language picked for the open video only leaves the account's default language as it is.
  func selectSubtitleLanguage(_ language: String, remembers: Bool) {
    selectedSubtitleLanguage = language
    if remembers { updateSettings { $0.defaultSubtitleLanguage = language } }
    if let item = player.currentItem {
      configureSubtitles(for: item)
    }
    reloadNativeSubtitles()
  }

  func setCaptionStyles(_ styles: LiveCaptionStyles) {
    guard settings.captionStyles != styles else { return }
    updateSettings { $0.captionStyles = styles }
  }
}
