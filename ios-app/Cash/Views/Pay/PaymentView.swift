import SwiftUI

/// **La schermata del video.**
///
/// Tutta la sequenza vive qui dentro, in un unico `ZStack`, e non in cinque
/// schermate che si sostituiscono. È una scelta precisa: la banconota è un
/// solo oggetto che si sposta, si rimpicciolisce e sparisce dentro l'avatar.
/// Se ogni fase fosse una schermata a sé, quel movimento continuo — che è poi
/// tutto il senso del design — non ci sarebbe.
///
/// ```
/// importo  →  armato  →  Face ID  →  invio  →  fatto
/// ```
struct PaymentView: View {

    @EnvironmentObject private var appState: AppState
    @StateObject private var flow: PaymentFlow
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
        .task(id: flow.phase) {
            await returnHomeAfterSuccess()
        }
    }

    // MARK: - La banconota che vola

    /// Il livello condiviso fra tutte le fasi. Posizione, dimensione e
    /// opacità sono funzioni della fase corrente: SwiftUI interpola il resto.
    private func banknoteLayer(size: CGSize) -> some View {
        BanknoteView(
            amount: flow.amount,
            handle: appState.handle,
            width: min(size.width - 56, 340)
        )
        .scaleEffect(noteScale)
        .opacity(noteOpacity)
        .position(x: size.width / 2, y: size.height * noteYFraction)
        .allowsHitTesting(false)
    }

    /// Fuori schermo in basso finché non serve, al centro-basso durante il
    /// Face ID, poi su dentro l'avatar.
    private var noteYFraction: CGFloat {
        switch flow.phase {
        case .composing, .armed, .failed: return 1.32
        case .authenticating:             return 0.68
        case .sending, .sent:             return recipientYFraction
        }
    }

    private var noteScale: CGFloat {
        switch flow.phase {
        case .composing, .armed, .failed: return 0.88
        case .authenticating:             return 1.0
        case .sending, .sent:             return 0.10
        }
    }

    private var noteOpacity: Double {
        switch flow.phase {
        case .authenticating: return 1
        // In `sending` va a zero *mentre* sale: la banconota non scompare,
        // viene assorbita dall'avatar.
        default:              return 0
        }
    }

    // MARK: - Anello Face ID

    private var ringLayer: some View {
        VStack {
            FaceIDRingView(isActive: flow.phase == .authenticating, size: 34)
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
    }

    // MARK: - Contenuto per fase

    @ViewBuilder
    private func phaseLayer(size: CGSize) -> some View {
        switch flow.phase {
        case .composing:
            composeLayer
                .transition(.opacity)

        case .armed:
            armedLayer
                .transition(.opacity)

        case .authenticating:
            // Volutamente vuoto: restano solo l'anello verde e la banconota,
            // come nel terzo frame del video.
            Color.clear

        case .sending:
            Color.clear

        case .sent:
            sentLayer
                .transition(.opacity)

        case .failed(let message):
            failedLayer(message)
                .transition(.opacity)
        }
    }

    // MARK: Fase 1 — importo

    private var composeLayer: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button {
                    onFinish()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.secondaryText)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.white.opacity(0.07)))
                }

                Spacer()

                HStack(spacing: 8) {
                    AvatarView(contact: flow.recipient, size: 28)
                    Text(flow.recipient.displayName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.primaryText)
                }

                Spacer()

                // Bilancia la X di sinistra e tiene il nome esattamente al centro.
                Color.clear.frame(width: 34, height: 34)
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)

            Spacer(minLength: 12)

            VStack(spacing: 10) {
                Text(flow.amountText)
                    .font(Theme.amount(74))
                    .foregroundStyle(flow.amount.isZero ? Theme.tertiaryText : Theme.primaryText)
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.35)
                    .lineLimit(1)
                    .padding(.horizontal, 24)
                    .animation(.smooth(duration: 0.22), value: flow.amount)

                if let issue = appState.validate(amount: flow.amount),
                   !flow.amount.isZero {
                    Text(issue.localizedDescription)
                        .font(Theme.caption)
                        .foregroundStyle(Theme.destructive)
                        .transition(.opacity)
                } else {
                    Text("Saldo \(appState.balance.formatted())")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.tertiaryText)
                }
            }

            Spacer(minLength: 12)

            KeypadView(
                onDigit: { flow.type($0) },
                onDelete: { flow.deleteDigit() }
            )
            .padding(.horizontal, 44)

            Button {
                flow.arm()
            } label: {
                Text("Continua").frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle(isEnabled: flow.isAmountValid))
            .disabled(!flow.isAmountValid)
            .padding(.horizontal, Theme.screenPadding)
            .padding(.top, 20)
            .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Fase 2 — armato, in attesa del gesto

    private var armedLayer: some View {
        ZStack {
            // Il doppio tocco vale su tutto lo schermo, non su un pulsante:
            // nel video non c'è nulla da centrare col dito, si tocca e basta.
            Color.black.opacity(0.001)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    Task { await flow.confirm() }
                }

            HStack(alignment: .center, spacing: 26) {
                Text(flow.amountText)
                    .font(Theme.amount(76))
                    .foregroundStyle(Theme.primaryText)
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)

                PayHintView(text: Copy.payHint)
            }
            .padding(.horizontal, 24)

            VStack {
                Spacer()
                Button {
                    flow.disarm()
                } label: {
                    Text("Cambia importo")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.secondaryText)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                }
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Fase 5 — fatto

    private var sentLayer: some View {
        VStack(spacing: 20) {
            CheckmarkView(size: 54, lineWidth: 2)

            Text(Copy.sent(to: flow.recipient.displayName))
                .font(.system(size: 15, weight: .regular))
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

                Button {
                    onFinish()
                } label: {
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

    /// Dopo la conferma la schermata si chiude da sola: il video non ha un
    /// pulsante "Fine", e chiedere un tocco in più dopo che il pagamento è
    /// già andato sarebbe un passaggio a vuoto.
    private func returnHomeAfterSuccess() async {
        guard flow.phase == .sent else { return }
        try? await Task.sleep(nanoseconds: 2_200_000_000)
        guard !Task.isCancelled else { return }
        onFinish()
    }
}
