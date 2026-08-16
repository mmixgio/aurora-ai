import SwiftUI

/// Il punto di ingresso.
///
/// Una sola finestra, sempre in scuro: l'app è pensata per il nero pieno e in
/// chiaro non avrebbe senso, quindi non lascia nemmeno la possibilità.
///
/// Nessuna rete, nessun account, nessun analytics: tutto ciò che l'app sa sta
/// sul telefono di chi la usa.
@main
struct CashApp: App {

    @StateObject private var appState = AppState()
    @StateObject private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(router)
                .preferredColorScheme(.dark)
                .tint(.white)
        }
    }
}
