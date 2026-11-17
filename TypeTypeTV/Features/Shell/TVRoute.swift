import Foundation

enum TVRoute: Hashable {
  case detail(LiveVideoItem)
  case channel(String)
  case playlist(LivePlaylistResult)
  case twitch(LiveTwitchRoute)
  case twitchSearch(String)
}

enum TVTab: Hashable {
  case home
  case subscriptions
  case twitch
  case search
  case library
  case settings
}
