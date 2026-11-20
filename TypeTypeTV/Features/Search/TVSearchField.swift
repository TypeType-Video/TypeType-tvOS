import SwiftUI

struct TVSearchField: View {
  @Binding var query: String
  let recent: [String]
  var focus: FocusState<Bool>.Binding
  @State private var typed = ""

  var body: some View {
    ZStack {
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
      TVQueryField(query: query, recent: recent, focused: focus.wrappedValue)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
    .frame(height: 96)
    .onChange(of: focus.wrappedValue) { _, focused in if focused { typed = query } }
    .onChange(of: typed) { _, text in query = LiveSearchInput.normalized(text) }
  }
}
