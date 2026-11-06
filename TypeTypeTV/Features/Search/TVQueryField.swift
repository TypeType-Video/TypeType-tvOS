import SwiftUI

// Android TV's QueryField: the query with a blinking cursor, and while it is empty a translucent ghost that types
// "Type anything" and then the recent searches, one after another. Only this view redraws while it animates.
struct TVQueryField: View {
  let query: String
  let recent: [String]
  @State private var phrase = 0
  @State private var shown = 0
  @State private var cursorOn = true

  private static let blink: Duration = .milliseconds(530)

  var body: some View {
    HStack(spacing: 20) {
      Image(systemName: "magnifyingglass").font(.system(size: 34, weight: .medium)).foregroundStyle(TVPalette.textMid)
      HStack(spacing: 4) {
        Text(verbatim: line).foregroundStyle(TVPalette.textHigh.opacity(query.isEmpty ? 0.42 : 1)).lineLimit(1)
        Capsule().fill(TVPalette.accent).frame(width: 4, height: 44).opacity(cursorOn ? 1 : 0)
      }
      .font(TVType.title)
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 28)
    .frame(height: 96)
    .background(TVPalette.surface, in: RoundedRectangle(cornerRadius: TVDimens.panelRadius))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(query.isEmpty ? Text("Type anything") : Text(verbatim: query))
    .task(id: GhostKey(empty: query.isEmpty, phrases: phrases)) {
      if query.isEmpty { await ghostWrite() } else { await blinkForever() }
    }
  }

  private struct GhostKey: Hashable {
    let empty: Bool
    let phrases: [String]
  }

  private var phrases: [String] {
    let placeholder = String(localized: "Type anything")
    return [placeholder] + recent.map { String($0.prefix(32)) }.filter { $0 != placeholder }.prefix(5)
  }

  private var line: String {
    guard query.isEmpty else { return query }
    let current = phrases[min(phrase, phrases.count - 1)]
    return String(current.prefix(shown))
  }

  private func blinkForever() async {
    while !Task.isCancelled {
      cursorOn = true
      guard (try? await Task.sleep(for: Self.blink)) != nil else { return }
      cursorOn = false
      guard (try? await Task.sleep(for: Self.blink)) != nil else { return }
    }
  }

  // Types at a hand's uneven pace, rests with a blinking cursor, then erases faster than it typed.
  private func ghostWrite() async {
    let list = phrases
    shown = 0
    while !Task.isCancelled {
      for (index, text) in list.enumerated() {
        phrase = index
        cursorOn = true
        for letter in 0...text.count {
          shown = letter
          guard (try? await Task.sleep(for: .milliseconds(60 + (letter * 37 + index * 11) % 50))) != nil else { return }
        }
        if list.count == 1 { return await blinkForever() }
        for _ in 0..<4 {
          cursorOn.toggle()
          guard (try? await Task.sleep(for: Self.blink)) != nil else { return }
        }
        cursorOn = true
        for letter in stride(from: text.count - 1, through: 0, by: -1) {
          shown = letter
          guard (try? await Task.sleep(for: .milliseconds(28))) != nil else { return }
        }
        guard (try? await Task.sleep(for: .milliseconds(420))) != nil else { return }
      }
    }
  }
}
