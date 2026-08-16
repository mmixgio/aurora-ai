import Foundation

/// La tinta dell'avatar per chi non ha una foto.
///
/// Derivata dal nome e da nient'altro: lo stesso contatto ha sempre lo stesso
/// colore, su qualsiasi dispositivo e dopo qualsiasi reinstallazione, senza
/// che l'app debba salvare niente.
///
/// Restituisce numeri e non un `Color` di proposito: così questo pezzo di
/// logica resta verificabile senza tirare dentro SwiftUI.
enum DeterministicColor {

    /// Tonalità in 0…1.
    static func hue(for name: String) -> Double {
        // Somma dei punti di codice: stabile fra versioni di Swift, al
        // contrario di `hashValue`, che è volutamente randomizzato a ogni
        // avvio e produrrebbe un colore diverso ogni volta.
        let sum = name.unicodeScalars.reduce(into: 0) { total, scalar in
            total &+= Int(scalar.value)
        }
        return Double(sum % 360) / 360.0
    }

    /// Le due tinte del gradiente di sfondo, dalla più chiara alla più scura.
    static func gradientComponents(for name: String) -> (
        top: (hue: Double, saturation: Double, brightness: Double),
        bottom: (hue: Double, saturation: Double, brightness: Double)
    ) {
        let h = hue(for: name)
        return (
            top: (h, 0.28, 0.30),
            bottom: (h, 0.35, 0.16)
        )
    }
}
