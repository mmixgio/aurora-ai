import Foundation

/// La logica del profilo.
///
/// Esiste perché la schermata non debba chiamare `LocalAuthentication` per
/// sapere cosa scrivere accanto a "Autenticazione".
@MainActor
final class SettingsViewModel: ObservableObject {

    @Published var signatureDraft = ""

    private let biometrics: BiometricAuthenticating

    init(biometrics: BiometricAuthenticating = BiometricService()) {
        self.biometrics = biometrics
    }

    var authenticationLabel: String {
        biometrics.availableMethod().label
    }

    var confirmationLabel: String {
        ApplePayConfiguration.isAvailable ? "Apple Pay" : "Pulsante di conferma"
    }

    /// L'anteprima di ciò che verrà stampato, normalizzata a ogni tasto.
    var signaturePreview: String {
        UserSignature.normalize(signatureDraft)
    }

    func load(current signature: String) {
        signatureDraft = signature
    }
}
