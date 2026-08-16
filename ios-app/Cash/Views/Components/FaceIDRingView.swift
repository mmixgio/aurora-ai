import SwiftUI

/// L'anello verde che compare in alto durante l'autenticazione, quello del
/// terzo frame del video.
///
/// Sta vicino alla fotocamera frontale, dove guardi mentre il Face ID ti
/// scansiona: è quel dettaglio a far sembrare che l'app stia leggendo il
/// viso, anche se il riconoscimento vero lo fa iOS nel suo pannello.
struct FaceIDRingView: View {

    /// A `false` l'anello si spegne e si contrae.
    var isActive: Bool = true
    var size: CGFloat = 34

    @State private var rotation: Double = 0
    @State private var pulse: Bool = false

    var body: some View {
        ZStack {
            // Il cerchio di base, sempre presente ma tenue.
            Circle()
                .stroke(Theme.faceID.opacity(0.28), lineWidth: 2.5)

            // L'arco che gira: è questo a dare il senso di "sta lavorando".
            Circle()
                .trim(from: 0.0, to: 0.32)
                .stroke(
                    Theme.faceID,
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                )
                .rotationEffect(.degrees(rotation))
        }
        .frame(width: size, height: size)
        .shadow(color: Theme.faceID.opacity(0.55), radius: pulse ? 12 : 5)
        .scaleEffect(isActive ? (pulse ? 1.06 : 0.97) : 0.6)
        .opacity(isActive ? 1 : 0)
        .animation(.smooth(duration: 0.35), value: isActive)
        .onAppear { startAnimating() }
        .onChange(of: isActive) { _, nowActive in
            if nowActive { startAnimating() }
        }
    }

    private func startAnimating() {
        guard isActive else { return }

        rotation = 0
        withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
            rotation = 360
        }
        withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
            pulse = true
        }
    }
}
