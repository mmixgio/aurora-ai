import SwiftUI

/// L'importo a tutto schermo, regolabile senza tastierino.
///
/// La parte intera e i centesimi sono due zone toccabili: quella attiva è
/// bianca, l'altra spenta, e una sottolineatura scivola dall'una all'altra
/// per dire dove finiranno i prossimi colpi di volume.
///
/// Per VoiceOver è un unico controllo regolabile: scorrendo su e giù si
/// muove l'importo, esattamente come con i tasti fisici.
struct AmountView: View {

    let amount: Money
    @Binding var field: AmountField

    /// Chiamata con `+1` o `-1`.
    let onStep: (Int) -> Void

    /// Corpo della parte intera; il resto è proporzionato a questo.
    var size: CGFloat = 76

    @ScaledMetric(relativeTo: .largeTitle) private var scaleFactor: CGFloat = 1
    @Namespace private var underline

    private var currency: Currency { AppConfiguration.currency }

    /// Il corpo segue Dynamic Type, ma senza esplodere: oltre una certa
    /// dimensione l'importo non entrerebbe più nello schermo.
    private var resolvedSize: CGFloat {
        min(size * scaleFactor, size * 1.35)
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            Text(currency.symbol)
                .font(.system(size: resolvedSize * 0.52, weight: .regular))
                .foregroundStyle(Theme.secondaryText)
                .padding(.trailing, 4)

            part(text: amount.unitsText(currency: currency), target: .units, size: resolvedSize)

            Text(currency.decimalSeparator)
                .font(.system(size: resolvedSize * 0.55, weight: .medium))
                .foregroundStyle(field == .cents ? Theme.primaryText : Theme.tertiaryText)

            part(text: amount.fractionText, target: .cents, size: resolvedSize * 0.55)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.4)
        .padding(.horizontal, 20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Importo, regola \(field.accessibilityName)")
        .accessibilityValue(amount.formattedExact())
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onStep(1)
            case .decrement: onStep(-1)
            @unknown default: break
            }
        }
    }

    private func part(text: String, target: AmountField, size: CGFloat) -> some View {
        let isSelected = field == target

        return Text(text)
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(isSelected ? Theme.primaryText : Theme.tertiaryText)
            // Le cifre scorrono invece di essere sostituite: tenendo premuto
            // il volume l'importo sembra un contatore che gira.
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
    }

    private func select(_ target: AmountField) {
        guard field != target else { return }
        withAnimation(Motion.detail) { field = target }
        Haptics.selection()
    }
}
