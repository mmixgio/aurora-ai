import SwiftUI

/// L'anello che compare in alto durante l'autenticazione.
///
/// Sta vicino alla fotocamera frontale, dove si guarda mentre il viso viene
/// scansionato: è quel dettaglio a far sembrare che l'app stia leggendo,
/// anche se il riconoscimento vero lo fa iOS nel suo pannello.
struct AuthenticationRingView: View {

    var isActive: Bool = true
    var size: CGFloat = 34

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rotation: Double = 0
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.authentication.opacity(0.28), lineWidth: 2.5)

            // L'arco che gira: è questo a dare il senso di "sta lavorando".
            Circle()
                .trim(from: 0, to: 0.32)
                .stroke(Theme.authentication, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(rotation))
        }
        .frame(width: size, height: size)
        .shadow(color: Theme.authentication.opacity(0.55), radius: pulse ? 12 : 5)
        .scaleEffect(isActive ? (pulse ? 1.06 : 0.97) : 0.6)
        .opacity(isActive ? 1 : 0)
        .animation(Motion.detail, value: isActive)
        .onAppear(perform: startAnimating)
        .onChange(of: isActive) { _, active in
            if active { startAnimating() }
        }
        .accessibilityHidden(true)
    }

    private func startAnimating() {
        guard isActive, !reduceMotion else { return }

        rotation = 0
        withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
            rotation = 360
        }
        withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
            pulse = true
        }
    }
}
