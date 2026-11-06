import SwiftUI

@main
struct TypeTypeTVApp: App {
    var body: some Scene {
        WindowGroup {
            VStack(spacing: 32) {
                Image("TypeTypeLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 160, height: 160)
                    .accessibilityHidden(true)
                Text(verbatim: "TypeType")
                    .font(.system(size: 76, weight: .bold))
            }
        }
    }
}
