import SwiftUI

// Selecting the bar opens the system keyboard: Siri dictation and typing from an iPhone only exist there. The
// text field is nearly transparent so the drawn query, with its cursor and ghost text, stays what is seen.
struct TVSearchField: View {
  @Binding var query: String
  let recent: [String]
  var focus: FocusState<Bool>.Binding
  @State private var typed = ""

  var body: some View {
    ZStack {
      TVQueryField(query: query, recent: recent, focused: focus.wrappedValue)
        .accessibilityHidden(true)
      TextField("", text: $typed)
        .textFieldStyle(.plain)
        .foregroundStyle(.clear)
        .tint(.clear)
        .opacity(0.02)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .submitLabel(.search)
        .focused(focus)
        .accessibilityLabel(Text("Search"))
        .accessibilityValue(Text(verbatim: query))
    }
    .frame(height: 96)
    .onChange(of: focus.wrappedValue) { _, focused in if focused { typed = query } }
    .onChange(of: typed) { _, text in query = LiveSearchInput.normalized(text) }
  }
}
