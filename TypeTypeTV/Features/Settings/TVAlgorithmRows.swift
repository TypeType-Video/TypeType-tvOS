import SwiftUI

struct TVAlgorithmRows: View {
  @StateObject private var model: LiveAlgorithmViewModel
  @Binding var picker: TVPickerRequest?

  init(service: LiveRecommenderServiceProtocol, picker: Binding<TVPickerRequest?>) {
    _model = StateObject(wrappedValue: LiveAlgorithmViewModel(service: service, feedback: nil))
    _picker = picker
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      if model.loaded {
        TVSettingRow(systemImage: "slider.horizontal.3", title: "Home page by algorithm",
                     summary: model.settings.enabled
                       ? "On. Turn it off to get the standard home page back."
                       : "Off. You keep the standard home page until you turn it on.",
                     trailing: .toggle(model.settings.enabled)) {
          model.setEnabled(!model.settings.enabled)
          NotificationCenter.default.post(name: .liveSettingsDidChange, object: nil)
        }
        if model.settings.enabled, let current = model.current {
          TVSettingRow(systemImage: "list.bullet.rectangle", title: "Home page algorithm",
                       summary: LocalizedStringKey(current.description), trailing: .value(current.name)) {
            picker = TVPickerRequest(
              origin: "list.bullet.rectangle", title: "Home page algorithm",
              summary: "The algorithm decides which videos appear on your home page and in what order. Nothing else changes: search, subscriptions and history stay the same.",
              choices: model.algorithms.map { TVChoice(id: $0.id, label: $0.name) }, selected: current.id
            ) { id in
              model.select(id)
              NotificationCenter.default.post(name: .liveSettingsDidChange, object: nil)
            }
          }
        }
      }
    }
    .task { await model.load() }
  }
}
