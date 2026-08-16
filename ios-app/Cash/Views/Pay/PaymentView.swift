import SwiftUI

/// **La schermata del pagamento.**
///
/// Tutte le fasi vivono qui dentro, in un unico `ZStack`, e non in cinque
/// schermate che si sostituiscono. È una scelta precisa: la banconota è un
/// solo oggetto che sale, si rimpicciolisce e sparisce dentro l'avatar. Se
/// ogni fase fosse una schermata a sé, quel movimento continuo — che è poi
/// tutto il senso del design — non ci sarebbe.
///
/// ```
/// importo  →  conferma  →  Face ID  →  invio  →  fatto
/// ```
struct PaymentView: View {

    @EnvironmentObject private var appState: AppState
    @StateObject private var flow: PaymentFlow
    @StateObject private var volume = VolumeButtonService()

    let onFinish: () -> Void

    @MainActor
    init(recipient: Contact, appState: AppState, onFinish: @escaping () -> Void) {
        _flow = StateObject(wrappedValue: PaymentFlow(recipient: recipient, appState: appState))
        self.onFinish = onFinish
    }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size

            ZStack {
                banknoteLayer(size: size)
                ringLayer
                recipientLayer(size: size)
                phaseLayer(size: size)
            }
            .frame(width: size.width, height: size.height)
        }
        .cashBackground()
        .toolbar(.hidden, for: .navigationBar)
        .onAppear(perform: startListeningToVolume)
        .onDisappear { volume.stop() }
        .onChange(of: flow.phase) { _, phase in
            // I tasti del volume tornano a fare il loro mestiere appena si
            // esce dalla regolazione dell'importo.
            if phase == .composing {
                volume.start()
            } else {
                volume.stop()
            }
        }
        .task(id: flow.phase) {
            await returnHomeAfterSuccess()
        }
    }

    private func startListeningToVolume() {
        volume.onPress = { direction in
            flow.step(direction == .up ? 1 : -1)
        }
        volume.start()
    }

    // MARK: - La banconota che vola

    /// Il livello condiviso da tutte le fasi. Posizione, scala, rotazione e
    /// opacità sono funzioni della fase: SwiftUI interpola il resto.
    private func banknoteLayer(size: CGSize) -> some View {
        BanknoteView(
            amount: flow.amount,
            handle: appState.handle,
            width: min(size.width - 56, 340)
        )
        .scaleEffect(noteScale)
        .rotationEffect(.degrees(noteRotation))
        .opacity(noteOpacity)
        .position(x: size.width / 2, y: size.height * noteYFraction)
        .allowsHitTesting(false)
        .animation(noteAnimation, value: flow.phase)
    }

    /// Ogni tratto del percorso ha la sua curva: salire in campo è un
    /// movimento lento e pesante, essere assorbiti dall'avatar è un
    /// movimento deciso che frena senza rimbalzare.
    private var noteAnimation: Animation {
        switch flow.phase {
        case .authenticating: return Motion.noteRise
        case .sending, .sent: return Motion.noteFly
        default:              return Motion.phase
        }
    }

    private var noteYFraction: CGFloat {
        switch flow.phase {
        case .composing, .confirming, .failed: return 1.32   // fuori campo, in basso
        case .authenticating:                  return 0.68
        case .sending, .sent:                  return recipientYFraction
        }
    }

    private var noteScale: CGFloat {
        switch flow.phase {
        case .composing, .confirming, .failed: return 0.88
        case .authenticating:                  return 1.0
        case .sending, .sent:                  return 0.10
        }
    }

    /// Un'inclinazione appena accennata mentre vola: senza, il movimento
    /// sembra quello di un'immagine trascinata, non di un oggetto lanciato.
    private var noteRotation: Double {
        flow.phase == .sending || flow.phase == .sent ? -7 : 0
    }

    private var noteOpacity: Double {
        // In `sending` va a zero *mentre* sale: la banconota non scompare,
        // viene assorbita dall'avatar.
        flow.phase == .authenticating ? 1 : 0
    }

    // MARK: - Anello Face ID

    private var ringLayer: some View {
        VStack {
            // Durante Apple Pay l'anello non serve: il pannello di sistema
            // copre lo schermo e disegnargli qualcosa dietro è sprecato.
            FaceIDRingView(
                isActive: flow.phase == .authenticating
                    && flow.confirmationMethod == .biometrics,
                size: 34
            )
                .padding(.top, 4)
            Spacer()
        }
    }

    // MARK: - Destinatario

    private var recipientYFraction: CGFloat { 0.26 }

    private func recipientLayer(size: CGSize) -> some View {
        VStack(spacing: 12) {
            AvatarView(
                contact: flow.recipient,
                size: 78,
                isHighlighted: flow.phase == .sending
            )

            Text(flow.recipient.displayName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.secondaryText)
        }
        .position(x: size.width / 2, y: size.height * recipientYFraction)
        .opacity(flow.phase == .sending ? 1 : 0)
        .scaleEffect(flow.phase == .sending ? 1 : 0.88)
        .allowsHitTesting(false)
        .animation(Motion.phase, value: flow.phase)
    }

    // MARK: - Contenuto per fase

    @ViewBuilder
    private func phaseLayer(size: CGSize) -> some View {
        switch flow.phase {
        case .composing:
            composeLayer.transition(.phaseChange)

        case .confirming:
            confirmLayer.transition(.phaseChange)

        case .authenticating, .sending:
            // Volutamente vuoto: restano solo l'anello verde e la banconota.
            Color.clear

        case .sent:
            sentLayer.transition(.phaseChange)

        case .failed(let message):
            failedLayer(message).transition(.phaseChange)
        }
    }

    // MARK: Fase 1 — importo

    private var composeLayer: some View {
        VStack(spacing: 0) {
            header

            Spacer(minLength: 16)

            AmountFieldView(
                amount: flow.amount,
                field: editingFieldBinding,
                onStep: { flow.step($0) },
                size: 76,
                volumeUnavailable: !volume.isListening
            )

            if let issue = appState.validate(amount: flow.amount), !flow.amount.isZero {
                Text(issue.localizedDescription)
                    .font(Theme.caption)
                    .foregroundStyle(Theme.destructive)
                    .padding(.top, 16)
                    .transition(.riseUp)
            } else {
                Text("Saldo \(appState.balance.formatted())")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.tertiaryText)
                    .padding(.top, 16)
            }

            Spacer(minLength: 16)

            Button {
                flow.review()
            } label: {
                Text("Continua").frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle(isEnabled: flow.isAmountValid))
            .disabled(!flow.isAmountValid)
            .padding(.horizontal, Theme.screenPadding)
            .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(Motion.detail, value: flow.amount)
    }

    /// Cambiare parte azzera anche l'accelerazione: il primo tocco sui
    /// centesimi non deve ereditare la velocità accumulata sugli euro.
    private var editingFieldBinding: Binding<AmountField> {
        Binding(
            get: { flow.editingField },
            set: { newValue in
                flow.editingField = newValue
                flow.resetStepAcceleration()
            }
        )
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button(action: onFinish) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.secondaryText)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.white.opacity(0.07)))
            }
            .accessibilityLabel("Annulla")

            Spacer()

            HStack(spacing: 8) {
                AvatarView(contact: flow.recipient, size: 28)
                Text(flow.recipient.displayName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.primaryText)
            }

            Spacer()

            // Bilancia la X e tiene il nome esattamente al centro.
            Color.clear.frame(width: 34, height: 34)
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
    }

    // MARK: Fase 2 — conferma

    private var confirmLayer: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            VStack(spacing: 14) {
                AvatarView(contact: flow.recipient, size: 68)

                Text("a \(flow.recipient.displayName)")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.secondaryText)
            }

            Spacer(minLength: 20)

            Text(flow.amountText)
                .font(Theme.amount(76))
                .foregroundStyle(Theme.primaryText)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .padding(.horizontal, 24)

            Spacer(minLength: 20)

            VStack(spacing: 14) {
                confirmButton

                Label(confirmPrompt, systemImage: confirmPromptIcon)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.tertiaryText)

                Button {
                    flow.edit()
                } label: {
                    Text("Modifica importo")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.secondaryText)
                        .padding(.vertical, 6)
                }
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.bottom, 22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Quando Apple Pay è configurato la conferma è il suo pulsante ufficiale,
    /// e da lì in poi comanda il pannello di sistema — doppio clic del tasto
    /// laterale compreso.
    @ViewBuilder
    private var confirmButton: some View {
        switch flow.confirmationMethod {
        case .applePay:
            ApplePayButton {
                Task { await flow.confirm() }
            }
            .frame(height: 54)

        case .biometrics:
            Button {
                Task { await flow.confirm() }
            } label: {
                Text(Copy.confirmPayment).frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    /// Il testo cita il metodo che l'iPhone ha davvero: promettere il Face ID
    /// a chi ha solo il codice sarebbe una bugia scritta a schermo.
    private var confirmPrompt: String {
        if flow.confirmationMethod == .applePay {
            return "Doppio clic sul tasto laterale per pagare"
        }

        switch BiometricService.availableBiometry() {
        case .faceID: return "Ti verrà chiesto il Face ID"
        case .touchID: return "Ti verrà chiesto il Touch ID"
        case .passcodeOnly: return "Ti verrà chiesto il codice"
        case .unavailable: return "Nessuna autenticazione disponibile"
        }
    }

    private var confirmPromptIcon: String {
        flow.confirmationMethod == .applePay ? "creditcard" : "faceid"
    }

    // MARK: Fase 5 — fatto

    private var sentLayer: some View {
        VStack(spacing: 20) {
            CheckmarkView(size: 54, lineWidth: 2)

            Text(Copy.sent(to: flow.recipient.displayName))
                .font(.system(size: 15))
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { onFinish() }
    }

    // MARK: Errore

    private func failedLayer(_ message: String) -> some View {
        VStack(spacing: 18) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Theme.destructive)

            Text(message)
                .font(Theme.body)
                .foregroundStyle(Theme.primaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 40)

            VStack(spacing: 10) {
                Button {
                    flow.recoverFromFailure()
                } label: {
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

    // MARK: - Ritorno alla home

    /// Dopo la conferma la schermata si chiude da sola: chiedere un tocco in
    /// più quando il pagamento è già andato sarebbe un passaggio a vuoto.
    private func returnHomeAfterSuccess() async {
        guard flow.phase == .sent else { return }
        try? await Task.sleep(nanoseconds: 2_200_000_000)
        guard !Task.isCancelled else { return }
        onFinish()
    }
}
