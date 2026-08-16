import SwiftUI

/// **La schermata del pagamento.**
///
/// Tutte le fasi vivono qui dentro, in un unico `ZStack`, e non in cinque
/// schermate che si sostituiscono. È una scelta precisa: la banconota è **lo
/// stesso oggetto** dall'inizio alla fine, e sono posizione, scala, rotazione
/// e opacità a cambiare. Se ogni fase fosse una schermata a sé, quel
/// movimento continuo — che è poi tutto il senso del design — non ci sarebbe.
///
/// ```
/// importo  →  conferma  →  autenticazione  →  invio  →  fatto
/// ```
struct PaymentView: View {

    @EnvironmentObject private var appState: AppState
    @StateObject private var model: PaymentViewModel

    let onFinish: () -> Void

    @MainActor
    init(recipient: ContactPerson, ledger: PaymentLedger, onFinish: @escaping () -> Void) {
        _model = StateObject(wrappedValue: PaymentViewModel(
            recipient: recipient,
            ledger: ledger,
            volume: VolumeButtonService()
        ))
        self.onFinish = onFinish
    }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size

            ZStack {
                banknoteLayer(in: size)
                ringLayer
                recipientLayer(in: size)
                phaseLayer
            }
            .frame(width: size.width, height: size.height)
        }
        .cashBackground()
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { model.startListeningToHardware() }
        .onDisappear {
            model.stopListeningToHardware()
            model.cancelInFlight()
        }
        .onChange(of: model.phase) { _, phase in
            // I tasti del volume tornano a fare il loro mestiere appena si
            // esce dalla regolazione dell'importo.
            if phase.acceptsAmountInput {
                model.startListeningToHardware()
            } else {
                model.stopListeningToHardware()
            }
        }
        .task(id: model.phase) { await closeAfterCompletion() }
    }

    // MARK: - La banconota che vola

    /// Il livello condiviso da tutte le fasi: una sola istanza, collocata
    /// diversamente a seconda dello stato.
    private func banknoteLayer(in size: CGSize) -> some View {
        BanknoteView(
            amount: model.amount,
            signature: appState.signature,
            width: min(size.width - 56, 340)
        )
        .placed(placement, in: size)
        .allowsHitTesting(false)
        .animation(banknoteAnimation, value: model.phase)
    }

    private var placement: BanknotePlacement {
        switch model.phase {
        case .amount, .confirmation, .failed:
            return .hidden

        case .authentication:
            return BanknotePlacement(
                unitPosition: CGPoint(x: 0.5, y: 0.68),
                scale: 1.0,
                opacity: 1
            )

        case .sending, .completed:
            // Opacità a zero *mentre* sale, e un'inclinazione appena
            // accennata: senza, il movimento sembra quello di un'immagine
            // trascinata e non di un oggetto assorbito.
            return BanknotePlacement(
                unitPosition: recipientAnchor,
                scale: 0.10,
                rotationDegrees: -7,
                opacity: 0
            )
        }
    }

    /// Ogni tratto ha la sua curva: entrare in campo è lento e pesante,
    /// essere assorbiti è deciso e non rimbalza.
    private var banknoteAnimation: Animation {
        switch model.phase {
        case .authentication:   return Motion.noteRise
        case .sending, .completed: return Motion.noteFly
        default:                return Motion.phase
        }
    }

    // MARK: - Anello di autenticazione

    private var ringLayer: some View {
        VStack {
            AuthenticationRingView(
                // Durante Apple Pay il pannello di sistema copre lo schermo:
                // disegnargli qualcosa dietro sarebbe sprecato.
                isActive: model.phase == .authentication
                    && model.authorizationMethod != .applePay,
                size: 34
            )
            .padding(.top, 4)

            Spacer()
        }
    }

    // MARK: - Destinatario

    private let recipientAnchor = CGPoint(x: 0.5, y: 0.26)

    private func recipientLayer(in size: CGSize) -> some View {
        VStack(spacing: 12) {
            AvatarView(
                contact: model.recipient,
                size: 78,
                isHighlighted: model.phase == .sending
            )

            Text(model.recipient.displayName)
                .font(Theme.caption)
                .foregroundStyle(Theme.secondaryText)
        }
        .position(
            x: size.width * recipientAnchor.x,
            y: size.height * recipientAnchor.y
        )
        .opacity(model.phase == .sending ? 1 : 0)
        .scaleEffect(model.phase == .sending ? 1 : 0.88)
        .allowsHitTesting(false)
        .animation(Motion.phase, value: model.phase)
    }

    // MARK: - Contenuto per fase

    @ViewBuilder
    private var phaseLayer: some View {
        switch model.phase {
        case .amount:
            amountLayer.transition(.phaseChange)

        case .confirmation:
            confirmationLayer.transition(.phaseChange)

        case .authentication, .sending:
            // Volutamente vuoto: restano l'anello e la banconota.
            Color.clear

        case .completed:
            completedLayer.transition(.phaseChange)

        case .failed(let message):
            failureLayer(message).transition(.phaseChange)
        }
    }

    // MARK: Fase 1 — importo

    private var amountLayer: some View {
        VStack(spacing: 0) {
            header

            Spacer(minLength: 16)

            VStack(spacing: 22) {
                AmountView(
                    amount: model.amount,
                    field: model.editingFieldBinding,
                    onStep: model.step,
                    size: 76
                )

                VStack(spacing: 10) {
                    VolumeControl(
                        onStep: model.step,
                        hardwareAvailable: model.hardwareVolumeAvailable,
                        field: model.editingField
                    )

                    Text(hint)
                        .font(Theme.micro)
                        .foregroundStyle(Theme.tertiaryText)
                        .multilineTextAlignment(.center)
                        .id(hint)
                        .transition(.opacity)
                }
            }

            Text(footnote)
                .font(Theme.caption)
                .foregroundStyle(model.amountIssue() == nil ? Theme.tertiaryText : Theme.destructive)
                .padding(.top, 18)
                .padding(.horizontal, 24)
                .multilineTextAlignment(.center)
                .transition(.riseUp)

            Spacer(minLength: 16)

            Button(action: model.review) {
                Text(Copy.continueToConfirmation).frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle(isEnabled: model.isAmountValid))
            .disabled(!model.isAmountValid)
            .padding(.horizontal, Theme.screenPadding)
            .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(Motion.detail, value: model.amount)
    }

    private var hint: String {
        if !model.hardwareVolumeAvailable {
            return "Regola con i pulsanti qui sopra"
        }
        return model.editingField == .units
            ? "Tocca i centesimi per regolarli"
            : "Tocca gli euro per tornare al passo da 1"
    }

    private var footnote: String {
        model.amountIssue() ?? "Saldo \(appState.balance.formatted())"
    }

    private var header: some View {
        HStack(spacing: 10) {
            CloseButton(action: onFinish)

            Spacer()

            HStack(spacing: 8) {
                AvatarView(contact: model.recipient, size: 28)
                Text(model.recipient.displayName)
                    .font(Theme.bodyEmphasis)
                    .foregroundStyle(Theme.primaryText)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Destinatario \(model.recipient.fullName)")

            Spacer()

            // Bilancia la X e tiene il nome esattamente al centro.
            Color.clear.frame(width: 34, height: 34)
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
    }

    // MARK: Fase 2 — conferma

    private var confirmationLayer: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            VStack(spacing: 14) {
                AvatarView(contact: model.recipient, size: 68)

                Text("a \(model.recipient.displayName)")
                    .font(Theme.body)
                    .foregroundStyle(Theme.secondaryText)
            }

            Spacer(minLength: 20)

            Text(model.amount.formatted())
                .font(Theme.display(76))
                .foregroundStyle(Theme.primaryText)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .padding(.horizontal, 24)
                .accessibilityLabel("Importo da inviare")
                .accessibilityValue(model.amount.formattedExact())

            Spacer(minLength: 20)

            VStack(spacing: 14) {
                confirmButton

                Label(model.authorizationMethod.prompt, systemImage: promptIcon)
                    .font(Theme.micro)
                    .foregroundStyle(Theme.tertiaryText)

                Button(Copy.editAmount, action: model.editAmount)
                    .buttonStyle(QuietButtonStyle())
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.bottom, 22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Con Apple Pay configurato la conferma è il suo pulsante ufficiale, e da
    /// lì in poi comanda il pannello di sistema — doppio clic del tasto
    /// laterale compreso. Altrimenti è un pulsante normale seguito dal Face ID.
    @ViewBuilder
    private var confirmButton: some View {
        switch model.authorizationMethod {
        case .applePay:
            ApplePayButton(action: model.startConfirmation)
                .frame(height: Theme.controlHeight)
                .accessibilityLabel("Paga con Apple Pay")

        case .local:
            Button(action: model.startConfirmation) {
                Text(Copy.confirmPayment).frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    private var promptIcon: String {
        model.authorizationMethod == .applePay ? "creditcard" : "faceid"
    }

    // MARK: Fase 5 — completato

    private var completedLayer: some View {
        VStack(spacing: 20) {
            AnimatedCheckmark(size: 54, lineWidth: 2)

            Text(Copy.sent(to: model.recipient.displayName))
                .font(Theme.body)
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture(perform: onFinish)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Copy.sent(to: model.recipient.fullName))
        .accessibilityAddTraits(.isStaticText)
    }

    // MARK: Errore

    private func failureLayer(_ message: String) -> some View {
        VStack(spacing: 18) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Theme.destructive)
                .accessibilityHidden(true)

            Text(message)
                .font(Theme.body)
                .foregroundStyle(Theme.primaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 40)

            VStack(spacing: 10) {
                Button(action: model.recoverFromFailure) {
                    Text("Riprova").frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())

                Button(action: onFinish) {
                    Text("Annulla").frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Chiusura

    /// Dopo la conferma la schermata si chiude da sola: chiedere un tocco in
    /// più quando il pagamento è già andato sarebbe un passaggio a vuoto.
    private func closeAfterCompletion() async {
        guard model.phase.isTerminal else { return }
        try? await Task.sleep(for: Motion.completionHold)
        guard !Task.isCancelled else { return }
        onFinish()
    }
}
