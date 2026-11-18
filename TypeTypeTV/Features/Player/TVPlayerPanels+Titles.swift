import SwiftUI

extension TVPlayerPanel {
  var title: LocalizedStringKey {
    switch panel {
    case .menu: "Player options"
    case .chapters: "Chapters"
    case .quality: "Quality"
    case .audio: "Audio language"
    case .speed: "Playback speed"
    case .playlists: "Add to a playlist"
    case .comments: "Comments"
    case .queue: "Up next"
    case .captionStyle: "Subtitle style"
    case .info: "Description"
    case .channel: ""
    case .rewind: "Go back in the live"
    case .twitchChat: "Chat"
    }
  }
}
