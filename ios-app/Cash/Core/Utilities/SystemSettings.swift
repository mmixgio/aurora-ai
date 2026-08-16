import UIKit

/// L'unico punto da cui l'app manda l'utente nelle Impostazioni di iOS.
///
/// Esiste perché nessuna vista debba conoscere `UIApplication`: le schermate
/// dei permessi chiedono "portami nelle impostazioni" e non sanno come.
@MainActor
enum SystemSettings {

    static var canOpen: Bool {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    static func open() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
