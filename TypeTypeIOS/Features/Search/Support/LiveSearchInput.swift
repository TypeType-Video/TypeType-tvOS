import Foundation

// The typing rules of the Android TV on-screen keyboard: lower case, no leading or doubled space, 40 characters.
enum LiveSearchInput {
  static let keys = Array("abcdefghijklmnopqrstuvwxyz0123456789")
  static let keysPerRow = 9
  static let maxLength = 40

  static func append(_ query: String, _ character: Character) -> String {
    guard query.count < maxLength else { return query }
    if character == " ", query.isEmpty || query.hasSuffix(" ") { return query }
    return query + String(character)
  }

  static func delete(_ query: String) -> String {
    String(query.dropLast())
  }

  // Dictated or system-keyboard text goes through the same rules, so every query looks alike.
  static func normalized(_ text: String) -> String {
    text.reduce(into: "") { query, character in
      if character.isLetter || character.isNumber {
        query = append(query, Character(character.lowercased()))
      } else if character.isWhitespace {
        query = append(query, " ")
      }
    }
  }
}
