import SwiftUI

struct TVPasswordLoginForm: View {
  @ObservedObject var model: LiveAuthViewModel
  let onSubmit: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      if model.mode == .register {
        TextField(String(localized: "Display name"), text: $model.name)
          .textContentType(.name)
      }
      TextField(String(localized: "Email"), text: $model.identifier)
        .textContentType(.username)
        .keyboardType(.emailAddress)
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
      SecureField(String(localized: "Password"), text: $model.password)
        .textContentType(model.mode == .register ? .newPassword : .password)
        .onSubmit(onSubmit)
      HStack(spacing: 20) {
        Button(action: onSubmit) {
          Label(submitTitle, systemImage: "person.crop.circle.badge.checkmark")
        }
        .buttonStyle(.tvPillEmphasized)
        .disabled(!model.canSubmit)
        if model.registrationAllowed {
          Button {
            model.mode = model.mode == .register ? .signIn : .register
            model.clearError()
          } label: {
            Label(
              model.mode == .register ? "I already have an account" : "Create an account",
              systemImage: "person.badge.plus"
            )
          }
          .buttonStyle(.tvPill)
        }
      }
    }
  }

  private var submitTitle: LocalizedStringKey {
    if model.isLoading { return "Please wait" }
    return model.mode == .register ? "Register" : "Sign in"
  }
}
