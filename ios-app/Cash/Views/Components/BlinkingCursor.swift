import SwiftUI

/// La barretta lampeggiante accanto a "Double Click to Pay".
///
/// Nel video è una riga verticale bianca che pulsa come il cursore di un
/// campo di testo: dice "l'app è qui che aspetta te" meglio di qualsiasi
/// pulsante, e non aggiunge un solo elemento in più allo schermo.
struct BlinkingCursor: View {

    var height: CGFloat = 34
    var width: CGFloat = 2

    @State private var isVisible = true

    var body: some View {
        RoundedRectangle(cornerRadius: width / 2, style: .continuous)
            .fill(Theme.primaryText)
            .frame(width: width, height: height)
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                    isVisible = false
                }
            }
    }
}

/// Il testo del gesto con la sua barretta a fianco, come blocco unico.
struct PayHintView: View {

    var text: String = "Double Click\nto Pay"

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(text)
                .font(Theme.hint)
                .foregroundStyle(Theme.primaryText)
                .multilineTextAlignment(.leading)
                .lineSpacing(1)
                .fixedSize()

            BlinkingCursor(height: 36)
        }
    }
}
