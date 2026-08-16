import SwiftUI

/// La conferma finale: cerchio sottile con la spunta tracciata dentro.
///
/// Non è una `checkmark.circle` di sistema e non è un'immagine: la spunta
/// **viene disegnata**, e il cerchio si chiude attorno. Un secondo scarso, ma
/// è quello che fa sembrare il pagamento concluso davvero e non soltanto
/// dichiarato tale.
struct AnimatedCheckmark: View {

    var size: CGFloat = 54
    var lineWidth: CGFloat = 2

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var circleProgress: CGFloat = 0
    @State private var checkProgress: CGFloat = 0

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: circleProgress)
                .stroke(
                    Theme.primaryText.opacity(0.85),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                // Parte da ore 12 invece che da ore 3.
                .rotationEffect(.degrees(-90))

            CheckmarkShape()
                .trim(from: 0, to: checkProgress)
                .stroke(
                    Theme.primaryText,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                )
                .padding(size * 0.24)
        }
        .frame(width: size, height: size)
        .onAppear(perform: draw)
        .accessibilityHidden(true)
    }

    private func draw() {
        guard !reduceMotion else {
            circleProgress = 1
            checkProgress = 1
            return
        }

        withAnimation(.easeOut(duration: 0.45)) {
            circleProgress = 1
        }
        // La spunta parte a metà del cerchio: le due animazioni si
        // accavallano e il tutto sembra un gesto solo.
        withAnimation(.easeOut(duration: 0.35).delay(0.22)) {
            checkProgress = 1
        }
    }
}

/// La forma della spunta, in coordinate relative al riquadro che la contiene.
struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.04, y: rect.height * 0.52))
        path.addLine(to: CGPoint(x: rect.width * 0.38, y: rect.height * 0.84))
        path.addLine(to: CGPoint(x: rect.width * 0.96, y: rect.height * 0.18))
        return path
    }
}
