import SwiftUI

/// Il tastierino dell'importo.
///
/// Niente sfondi né bordi sui tasti: solo cifre grandi su nero, con un
/// cerchio che si accende sotto il dito. Meno elementi ci sono a schermo,
/// più l'importo al centro sembra grande.
struct KeypadView: View {

    let onDigit: (Int) -> Void
    let onDelete: () -> Void

    private let rows: [[Int]] = [
        [1, 2, 3],
        [4, 5, 6],
        [7, 8, 9]
    ]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(row, id: \.self) { digit in
                        KeypadKey(label: "\(digit)") { onDigit(digit) }
                    }
                }
            }

            HStack(spacing: 10) {
                // La casella vuota a sinistra tiene lo zero al centro,
                // allineato con il 2, il 5 e l'8.
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: 62)

                KeypadKey(label: "0") { onDigit(0) }

                KeypadKey(systemImage: "delete.left", action: onDelete)
            }
        }
    }
}

/// Un singolo tasto.
private struct KeypadKey: View {

    var label: String? = nil
    var systemImage: String? = nil
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(isPressed ? 0.12 : 0))
                    .frame(width: 62, height: 62)

                if let label {
                    Text(label)
                        .font(.system(size: 32, weight: .regular))
                        .foregroundStyle(Theme.primaryText)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 24, weight: .regular))
                        .foregroundStyle(Theme.primaryText.opacity(0.8))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.92 : 1)
        .animation(.smooth(duration: 0.18), value: isPressed)
        // `DragGesture` con distanza zero è il modo di sapere quando il dito
        // tocca e quando si stacca: `Button` da solo notifica solo il rilascio.
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}
