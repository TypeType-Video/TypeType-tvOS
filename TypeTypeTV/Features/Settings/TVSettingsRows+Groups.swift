import SwiftUI

extension TVSettingsRows {
  @ViewBuilder
  var blocked: some View {
    TVSettingRow(systemImage: "nosign", title: "Blocked channels", trailing: .value(String(model.blockedChannels.count)))
    ForEach(model.blockedChannels) { channel in
      TVSettingRow(systemImage: "person.crop.circle.badge.xmark", title: Text(verbatim: channel.name ?? channel.url),
                   summary: "Select to unblock this channel.") {
        Task { await model.unblock(channel) }
      }
    }
  }

  @ViewBuilder
  var performance: some View {
    TVSettingRow(systemImage: "play.rectangle", title: "Video previews",
                 summary: "Plays a muted preview behind the home page. Turn it off on a slow box.",
                 trailing: .toggle(videoPreviews)) { videoPreviews.toggle() }
    TVSettingRow(systemImage: "person.crop.circle.badge.clock", title: "Animated profile picture",
                 summary: "Plays an animated picture in the top bar. Turn it off on a slow box.",
                 trailing: .toggle(animatedAvatar)) { animatedAvatar.toggle() }
    TVSettingRow(systemImage: "photo", title: "Background picture",
                 summary: "Shows the selected video's picture behind the home and video pages. Turn it off on a slow box.",
                 trailing: .toggle(backdrop)) { backdrop.toggle() }
    TVSettingRow(systemImage: "sparkles", title: "Startup intro", summary: "The animation and sound when the app opens.",
                 trailing: .value(introLabel(intro))) {
      picker = TVPickerRequest(
        origin: "sparkles", title: "Startup intro", summary: "The animation and sound when the app opens.",
        choices: ["full", "short", "off"].map { TVChoice(id: $0, label: introLabel($0)) }, selected: intro
      ) { intro = $0 }
    }
    .focused(rowFocus, equals: "sparkles")
  }

  @ViewBuilder
  var account: some View {
    if let user = coordinator.currentUser {
      TVSettingRow(systemImage: "person", title: "Signed in as", trailing: .value(user.publicUsername ?? user.role.title))
      TVSettingRow(systemImage: "person.badge.key", title: "Role", trailing: .value(user.role.title))
    }
    if let unread = model.unreadNotifications {
      TVSettingRow(systemImage: "bell.badge", title: "Unread notifications", trailing: .value(String(unread)))
      if unread > 0 {
        TVSettingRow(systemImage: "checkmark.circle", title: "Mark all as read",
                     summary: "Clear the new-video notifications of this account.") {
          Task { await model.markNotificationsRead() }
        }
      }
    }
    TVSettingRow(systemImage: "rectangle.portrait.and.arrow.right", title: "Sign out",
                 summary: "Remove this session from the television.") {
      Task { await coordinator.signOut() }
    }
  }

  @ViewBuilder
  var instance: some View {
    if let instance = coordinator.instance {
      TVSettingRow(systemImage: "textformat", title: "Name", trailing: .value(instance.name))
      TVSettingRow(systemImage: "number", title: "Server version", trailing: .value(instance.version))
    }
    TVSettingRow(systemImage: "network", title: "Address", trailing: .value(coordinator.selectedServer?.baseURL?.host ?? ""))
    TVSettingRow(systemImage: "arrow.left.arrow.right", title: "Change instance",
                 summary: "Sign out and connect to another TypeType server.") { coordinator.showServerSetup() }
  }

  func toggle(
    _ systemImage: String, _ title: LocalizedStringKey, _ summary: LocalizedStringKey, _ isOn: Bool,
    _ edit: @escaping (inout LiveSettings) -> Void
  ) -> some View {
    TVSettingRow(systemImage: systemImage, title: title, summary: summary, trailing: .toggle(isOn)) {
      Task { await model.change(edit) }
    }
    .focused(rowFocus, equals: systemImage)
  }

  func choice(
    _ systemImage: String, _ title: LocalizedStringKey, _ summary: LocalizedStringKey, _ choices: [TVChoice],
    _ selected: String, _ edit: @escaping (String) -> (inout LiveSettings) -> Void
  ) -> some View {
    let label = choices.first { $0.id == selected }?.label ?? selected
    return TVSettingRow(systemImage: systemImage, title: title, summary: summary, trailing: .value(label)) {
      picker = TVPickerRequest(origin: systemImage, title: title, summary: summary, choices: choices, selected: selected) { value in
        Task { await model.change(edit(value)) }
      }
    }
    .focused(rowFocus, equals: systemImage)
  }

  static func qualityLabel(_ value: String) -> String {
    switch value {
    case "auto": String(localized: "Auto")
    case "2160p": "4K"
    default: value
    }
  }

  private func introLabel(_ value: String) -> String {
    switch value {
    case "short": String(localized: "Short")
    case "off": String(localized: "Off")
    default: String(localized: "Full")
    }
  }
}

extension Bundle {
  var version: String {
    let short = object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    let build = object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
    return build.isEmpty ? short : "\(short) (\(build))"
  }
}
