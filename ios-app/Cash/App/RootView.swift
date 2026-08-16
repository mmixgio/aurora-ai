import SwiftUI

/// La radice: onboarding oppure home, e gli avvisi comuni a tutta l'app.
struct RootView: View {

    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            if appState.isReadyToPay {
                HomeView().transition(.opacity)
            } else {
                WelcomeView().transition(.opacity)
            }
        }
        .animation(Motion.phase, value: appState.isReadyToPay)
        .alert(
            appState.alert?.title ?? "",
            isPresented: Binding(
                get: { appState.alert != nil },
                set: { if !$0 { appState.alert = nil } }
            ),
            presenting: appState.alert
        ) { _ in
            Button("Ho capito", role: .cancel) {}
        } message: { alert in
            Text(alert.message)
        }
    }
}
