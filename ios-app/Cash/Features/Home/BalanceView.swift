import SwiftUI

/// Il saldo in cima alla home.
///
/// Quando cambia, le cifre **scorrono** invece di essere sostituite di colpo:
/// dopo un pagamento è l'unico modo per vedere *quanto* è cambiato e non solo
/// che è cambiato.
struct BalanceView: View {

    let balance: Money

    var body: some View {
        VStack(spacing: 6) {
            Text("Saldo disponibile")
                .font(Theme.caption)
                .foregroundStyle(Theme.secondaryText)

            Text(balance.formatted())
                .font(Theme.display(52))
                .foregroundStyle(Theme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())
                .animation(Motion.phase, value: balance)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Saldo disponibile")
        .accessibilityValue(balance.formattedExact())
    }
}
