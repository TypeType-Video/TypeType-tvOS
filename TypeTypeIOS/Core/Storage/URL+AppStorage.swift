import Foundation

extension URL {
  static var appStorageDirectory: URL {
    #if os(tvOS)
    // tvOS refuses writes outside Caches; Application Support fails with a permission error.
    .cachesDirectory
    #else
    .applicationSupportDirectory
    #endif
  }
}
