import CoreMedia

extension PlaybackEngine {
  // How far the tracks still playing are buffered: the shortest of them is what playback can rely on.
  func bufferedUntil() -> TimeInterval? {
    let ends = tracks.values.filter { !$0.ended }.map(\.bufferedEnd).filter(\.isValid)
    return ends.min()?.seconds
  }
}
