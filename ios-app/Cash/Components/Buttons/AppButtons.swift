import SwiftUI

/// Il pulsante pieno dell'app: bianco su nero, angoli completamente tondi.
struct PrimaryButtonStyle: ButtonStyle {
    var isEnabled = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .default, weight: .semibold))
            .foregroundStyle(isEnabled ? Color.black : Color.white.opacity(0.35))
            .padding(.vertical, 17)
            .frame(minHeight: Theme.controlHeight)
            .background(Capsule().fill(isEnabled ? Color.white : Color.white.opacity(0.10)))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Motion.press, value: configuration.isPressed)
    }
}

/// La variante con il solo bordo, per le azioni secondarie.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .default, weight: .medium))
            .foregroundStyle(Theme.primaryText)
            .padding(.vertical, 17)
            .frame(minHeight: Theme.controlHeight)
            .background(Capsule().fill(Theme.surfaceRaised))
            .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Motion.press, value: configuration.isPressed)
    }
}

/// Un pulsante testuale discreto, per le uscite laterali.
struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.body)
            .foregroundStyle(Theme.secondaryText)
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(Motion.press, value: configuration.isPressed)
    }
}

/// Il tondino con la X in alto a sinistra.
struct CloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.secondaryText)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Theme.surfaceRaised))
        }
        .accessibilityLabel("Annulla")
    }
}
