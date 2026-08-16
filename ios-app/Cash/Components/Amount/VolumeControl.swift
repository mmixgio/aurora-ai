import SwiftUI

/// La pillola con "meno", il promemoria dei tasti e "più".
///
/// I due pulsanti non sono un ripiego estetico: i tasti del volume passano da
/// un meccanismo che Apple non garantisce, e nel simulatore non esistono
/// proprio. Se quel canale non c'è, l'app deve restare pienamente usabile —
/// quindi questi comandi ci sono sempre, e cambia solo la scritta in mezzo.
struct VolumeControl: View {

    let onStep: (Int) -> Void

    /// `false` quando i tasti fisici non sono disponibili.
    var hardwareAvailable: Bool = true

    /// Cosa si sta regolando, per l'etichetta di accessibilità.
    var field: AmountField = .units

    var body: some View {
        HStack(spacing: 0) {
            stepButton(systemImage: "minus", direction: -1, label: "Diminuisci")

            divider

            Label(
                hardwareAvailable ? "Tasti volume" : "Usa i pulsanti",
                systemImage: hardwareAvailable ? "speaker.wave.2" : "hand.tap"
            )
            .font(Theme.micro)
            .foregroundStyle(Theme.secondaryText)
            .padding(.horizontal, 14)
            .accessibilityHidden(true)

            divider

            stepButton(systemImage: "plus", direction: 1, label: "Aumenta")
        }
        .padding(4)
        .background(Capsule().fill(Theme.surfaceRaised))
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
                .frame(width: 44, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) \(field.accessibilityName.lowercased())")
    }
}
