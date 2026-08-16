import SwiftUI

/// L'importo a tutto schermo, regolabile con i tasti del volume.
///
/// Niente tastierino: la cifra è già lì e si muove. La parte intera e i
/// centesimi sono due zone toccabili separate — quella selezionata è bianca,
/// l'altra spenta — e una sottolineatura scivola dall'una all'altra per dire
/// dove finiranno i prossimi colpi di volume.
struct AmountFieldView: View {

    let amount: Money
    @Binding var field: AmountField

    /// Chiamata con `+1` o `-1` dai pulsanti a schermo.
    let onStep: (Int) -> Void

    /// Corpo della parte intera. I centesimi e il simbolo si ricavano da qui.
    var size: CGFloat = 76

    /// A `false` restano solo le cifre, senza la pillola dei comandi.
    var showsControls: Bool = true

    /// Mostrato quando i tasti del volume non hanno potuto attivarsi.
    var volumeUnavailable: Bool = false

    @Namespace private var underline

    private var currency: Currency { AppConfiguration.currency }

    var body: some View {
        VStack(spacing: 22) {
            digits

            if showsControls {
                VStack(spacing: 10) {
                    controls
                    caption
                }
            }
        }
    }

    // MARK: - Le cifre

    private var digits: some View {
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            Text(currency.symbol)
                .font(.system(size: size * 0.52, weight: .regular))
                .foregroundStyle(Theme.secondaryText)
                .padding(.trailing, 4)

            part(
                text: unitsText,
                target: .units,
                size: size
            )

            Text(currency.decimalSeparator)
                .font(.system(size: size * 0.55, weight: .medium))
                .foregroundStyle(field == .cents ? Theme.primaryText : Theme.tertiaryText)

            part(
                text: centsText,
                target: .cents,
                size: size * 0.55
            )
        }
        .lineLimit(1)
        .minimumScaleFactor(0.4)
        .padding(.horizontal, 20)
    }

    private func part(text: String, target: AmountField, size: CGFloat) -> some View {
        let isSelected = field == target

        return Text(text)
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(isSelected ? Theme.primaryText : Theme.tertiaryText)
            // Le cifre scorrono invece di essere sostituite di colpo: tenendo
            // premuto il volume l'importo sembra un contatore che gira.
            .contentTransition(.numericText())
            .overlay(alignment: .bottom) {
                if isSelected {
                    Capsule()
                        .fill(Theme.primaryText)
                        .frame(height: 2)
                        .offset(y: 8)
                        .matchedGeometryEffect(id: "amount-underline", in: underline)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { select(target) }
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(target == .units ? "Euro" : "Centesimi")
            .accessibilityValue(text)
    }

    // MARK: - I comandi

    /// La pillola con "meno", il promemoria dei tasti volume e "più".
    ///
    /// I due pulsanti non sono un ripiego estetico: i tasti del volume
    /// passano da un meccanismo non garantito da Apple, e se un giorno
    /// smettesse di funzionare l'app deve restare usabile.
    private var controls: some View {
        HStack(spacing: 0) {
            stepButton(systemImage: "minus", direction: -1, label: "Diminuisci")

            divider

            Label(
                volumeUnavailable ? "Usa i pulsanti" : "Tasti volume",
                systemImage: volumeUnavailable ? "hand.tap" : "speaker.wave.2"
            )
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Theme.secondaryText)
            .padding(.horizontal, 14)

            divider

            stepButton(systemImage: "plus", direction: 1, label: "Aumenta")
        }
        .padding(4)
        .background(
            Capsule().fill(Color.white.opacity(0.06))
        )
        .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(width: 1, height: 20)
    }

    private func stepButton(systemImage: String, direction: Int, label: String) -> some View {
        Button {
            onStep(direction)
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.primaryText)
                .frame(width: 40, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var caption: some View {
        Text(field == .units
             ? "Tocca i centesimi per regolarli"
             : "Tocca gli euro per tornare al passo da 1")
            .font(.system(size: 12))
            .foregroundStyle(Theme.tertiaryText)
            .transition(.opacity)
            .id(field)
    }

    // MARK: - Testi

    private var unitsText: String {
        String(amount.cents / 100)
    }

    private var centsText: String {
        String(format: "%02d", abs(amount.cents % 100))
    }

    private func select(_ target: AmountField) {
        guard field != target else { return }
        withAnimation(Motion.detail) { field = target }
        Haptics.tap()
    }
}
