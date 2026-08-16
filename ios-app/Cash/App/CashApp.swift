import SwiftUI

/// Il punto di ingresso.
///
/// Una sola finestra, sempre in scuro: l'app è pensata per il nero pieno e
/// in chiaro non avrebbe senso, quindi non lascia nemmeno la possibilità.
@main
struct CashApp: App {

    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
        }
    }
}
