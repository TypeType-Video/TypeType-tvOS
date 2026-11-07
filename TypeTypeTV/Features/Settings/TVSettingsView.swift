import SwiftUI

enum TVSettingsGroup: String, CaseIterable, Identifiable {
  case playback, content, blocked, performance, account, instance, about

  var id: String { rawValue }

  var title: LocalizedStringKey {
    switch self {
    case .playback: "Playback"
    case .content: "Content"
    case .blocked: "Blocked channels"
    case .performance: "Performance"
    case .account: "Account"
    case .instance: "Instance"
    case .about: "About"
    }
  }

  var systemImage: String {
    switch self {
    case .playback: "play.rectangle"
    case .content: "square.grid.2x2"
    case .blocked: "nosign"
    case .performance: "bolt"
    case .account: "person.crop.circle"
    case .instance: "server.rack"
    case .about: "info.circle"
    }
  }
}

struct TVPickerRequest: Identifiable {
  let id = UUID()
  let origin: String
  let title: LocalizedStringKey
  let summary: LocalizedStringKey?
  let choices: [TVChoice]
  let selected: String
  let apply: (String) -> Void
}

struct TVSettingsView: View {
  @ObservedObject var coordinator: RootCoordinator
  @StateObject private var model: LiveTVSettingsModel
  @State private var group = TVSettingsGroup.playback
  @State private var picker: TVPickerRequest?
  @FocusState private var railFocus: TVSettingsGroup?
  @Environment(\.tvContentFocusRequest) private var focusRequest
  @FocusState private var rowFocus: String?

  init(coordinator: RootCoordinator) {
    self.coordinator = coordinator
    _model = StateObject(wrappedValue: LiveTVSettingsModel(
      settingsService: coordinator.dependencies.settingsService,
      contentControls: coordinator.dependencies.contentControlsService,
      notifications: coordinator.dependencies.notificationsService
    ))
  }

  var body: some View {
    ZStack {
      HStack(alignment: .top, spacing: 64) {
        VStack(alignment: .leading, spacing: 12) {
          Text("Settings").font(TVType.headline).foregroundStyle(TVPalette.textHigh).padding(.bottom, 28)
          ForEach(TVSettingsGroup.allCases) { item in
            Button { railFocus = item } label: {
              Label(item.title, systemImage: item.systemImage)
            }
            .tvRailItem(item, selection: $group, focus: $railFocus)
          }
        }
        .focusSection()
        ScrollView(.vertical) {
          VStack(alignment: .leading, spacing: 18) {
            Text(group.title).textCase(.uppercase).font(TVType.label).tracking(3.6).foregroundStyle(TVPalette.textMid)
            TVSettingsRows(group: group, model: model, coordinator: coordinator, picker: $picker, rowFocus: $rowFocus)
            if let failure = model.failure {
              Text(verbatim: failure).font(TVType.meta).foregroundStyle(TVPalette.accentSoft)
            }
          }
          .padding(.vertical, 20)
          .padding(.horizontal, 24)
        }
        .padding(.horizontal, -24)
        .scrollTargetBehavior(TVEdgeScroll(rowPitch: 137))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .focusSection()
      }
      .padding(.leading, TVDimens.safeStart)
      .padding(.top, 40)
      .focusSection()
      .defaultFocus($railFocus, group, priority: .userInitiated)
      .onChange(of: focusRequest) { _, _ in railFocus = group }
      .disabled(picker != nil)
      if let picker {
        TVChoicePicker(title: picker.title, summary: picker.summary, choices: picker.choices, selected: picker.selected,
                       onPick: picker.apply) {
          let origin = picker.origin
          self.picker = nil
          Task { rowFocus = origin }
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .tvContentEdges()
    .background(TVPalette.ink.ignoresSafeArea())
    .task { await model.load() }
    .onChange(of: railFocus) { previous, focused in
      guard let focused else { return }
      if previous == nil, focused != group {
        railFocus = group
      } else {
        group = focused
      }
    }
  }
}
