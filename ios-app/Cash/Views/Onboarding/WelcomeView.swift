import SwiftUI

/// La prima schermata: il nome dell'app, una banconota che fluttua e un solo
/// pulsante. Serve a stabilire il tono prima ancora che tu tocchi qualcosa.
struct WelcomeView: View {

    @EnvironmentObject private var appState: AppState
    @State private var showsLinkAccount = false
    @State private var floats = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer(minLength: 40)

                BanknoteView(
                    amount: Money(units: 20),
                    handle: appState.handle,
                    width: 300
                )
                .rotation3DEffect(
                    .degrees(floats ? 5 : -5),
                    axis: (x: 1, y: 0.6, z: 0),
                    perspective: 0.6
                )
                .offset(y: floats ? -8 : 8)
                .animation(
                    .easeInOut(duration: 4).repeatForever(autoreverses: true),
                    value: floats
                )

                Spacer(minLength: 40)

                VStack(spacing: 14) {
                    Text("Cash")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(Theme.primaryText)

                    Text("Manda denaro con uno sguardo.\nNiente moduli, niente attese.")
                        .font(Theme.body)
                        .foregroundStyle(Theme.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }

                Spacer(minLength: 36)

                VStack(spacing: 16) {
                    Button {
                        showsLinkAccount = true
                    } label: {
                        Text("Collega il tuo conto")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    Text("Le coordinate restano sul telefono, protette dal Portachiavi.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.tertiaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .cashBackground()
            .navigationDestination(isPresented: $showsLinkAccount) {
                LinkAccountView()
            }
        }
        .onAppear { floats = true }
    }
}

/// Il pulsante pieno dell'app: bianco su nero, angoli completamente tondi.
struct PrimaryButtonStyle: ButtonStyle {
    var isEnabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(isEnabled ? Color.black : Color.white.opacity(0.35))
            .padding(.vertical, 17)
            .background(
                Capsule().fill(isEnabled ? Color.white : Color.white.opacity(0.10))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Motion.press, value: configuration.isPressed)
    }
}

/// La variante con il solo bordo, per le azioni secondarie.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(Theme.primaryText)
            .padding(.vertical, 17)
            .background(
                Capsule().fill(Color.white.opacity(0.07))
            )
            .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Motion.press, value: configuration.isPressed)
    }
}
