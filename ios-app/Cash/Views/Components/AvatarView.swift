import SwiftUI
import UIKit

/// Il cerchio con la foto del contatto, o le sue iniziali se la foto manca.
struct AvatarView: View {

    let contact: Contact
    var size: CGFloat = 72

    /// Alone luminoso attorno all'avatar, acceso quando il denaro sta arrivando.
    var isHighlighted: Bool = false

    var body: some View {
        ZStack {
            if let data = contact.imageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle().strokeBorder(Theme.hairline, lineWidth: 1)
        }
        .overlay {
            Circle()
                .stroke(Color.white.opacity(isHighlighted ? 0.9 : 0), lineWidth: 2)
                .blur(radius: 3)
        }
        .shadow(color: .white.opacity(isHighlighted ? 0.35 : 0), radius: 18)
        .animation(.smooth(duration: 0.4), value: isHighlighted)
    }

    /// Il fondo delle iniziali non è mai lo stesso grigio: la tinta viene dal
    /// nome, così ogni contatto è riconoscibile a colpo d'occhio anche senza foto.
    private var placeholder: some View {
        ZStack {
            Circle().fill(
                LinearGradient(
                    colors: [
                        Color(hue: hue, saturation: 0.28, brightness: 0.30),
                        Color(hue: hue, saturation: 0.35, brightness: 0.16)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            Text(contact.initials)
                .font(.system(size: size * 0.36, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.primaryText.opacity(0.92))
        }
    }

    private var hue: Double {
        // Somma dei codici dei caratteri riportata in 0…1: stesso nome,
        // sempre stesso colore, senza dover salvare niente.
        let sum = contact.fullName.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return Double(sum % 360) / 360.0
    }
}

/// Versione ridotta per lo storico, dove c'è solo il nome e nessuna foto.
struct InitialsBadge: View {
    let name: String
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            Circle().fill(Color(white: 0.10))
            Text(initials)
                .font(.system(size: size * 0.36, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.primaryText.opacity(0.85))
        }
        .frame(width: size, height: size)
        .overlay { Circle().strokeBorder(Theme.hairline, lineWidth: 1) }
    }

    private var initials: String {
        let letters = name
            .split(separator: " ")
            .compactMap { $0.first }
            .prefix(2)
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }
}
