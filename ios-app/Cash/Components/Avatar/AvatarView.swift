import SwiftUI
import UIKit

/// Il cerchio con la foto del contatto, o le sue iniziali se manca.
struct AvatarView: View {

    let contact: ContactPerson
    var size: CGFloat = 72

    /// Alone luminoso, acceso quando il denaro sta arrivando.
    var isHighlighted: Bool = false

    var body: some View {
        ZStack {
            if let data = contact.imageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                InitialsCircle(name: contact.fullName, initials: contact.initials, size: size)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay { Circle().strokeBorder(Theme.hairline, lineWidth: 1) }
        .overlay {
            Circle()
                .stroke(Color.white.opacity(isHighlighted ? 0.9 : 0), lineWidth: 2)
                .blur(radius: 3)
        }
        .shadow(color: .white.opacity(isHighlighted ? 0.35 : 0), radius: 18)
        .animation(Motion.phase, value: isHighlighted)
        .accessibilityHidden(true)
    }
}

/// Il cerchio con le iniziali.
///
/// La tinta viene dal nome e da nient'altro: lo stesso contatto ha sempre lo
/// stesso colore, senza che l'app debba salvarlo da nessuna parte.
struct InitialsCircle: View {

    let name: String
    let initials: String
    var size: CGFloat = 72

    var body: some View {
        let components = DeterministicColor.gradientComponents(for: name)

        ZStack {
            Circle().fill(
                LinearGradient(
                    colors: [
                        Color(hue: components.top.hue,
                              saturation: components.top.saturation,
                              brightness: components.top.brightness),
                        Color(hue: components.bottom.hue,
                              saturation: components.bottom.saturation,
                              brightness: components.bottom.brightness)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            Text(initials)
                .font(.system(size: size * 0.36, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.primaryText.opacity(0.92))
        }
        .frame(width: size, height: size)
    }
}

/// Versione ridotta per lo storico, dove del contatto resta solo il nome.
struct InitialsBadge: View {
    let name: String
    var size: CGFloat = 40

    var body: some View {
        InitialsCircle(name: name, initials: ContactPerson.initials(for: name), size: size)
            .clipShape(Circle())
            .overlay { Circle().strokeBorder(Theme.hairline, lineWidth: 1) }
            .accessibilityHidden(true)
    }
}
