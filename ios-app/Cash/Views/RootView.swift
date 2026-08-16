import SwiftUI

/// La radice dell'app: decide se mostrare l'onboarding o la home.
struct RootView: View {

    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            if appState.isReadyToPay {
                HomeView()
                    .transition(.opacity)
            } else {
                WelcomeView()
                    .transition(.opacity)
            }
        }
        .animation(Motion.phase, value: appState.isReadyToPay)
        .preferredColorScheme(.dark)
        .tint(.white)
    }
}
