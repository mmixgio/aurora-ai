import SwiftUI

/// La conferma finale: cerchio sottile con la spunta che si disegna dentro,
/// esattamente come nell'ultimo frame del video.
///
/// La spunta non compare: viene **tracciata**, e il cerchio si chiude
/// attorno. Un secondo scarso, ma è quello che fa sembrare il pagamento
/// concluso davvero e non solo dichiarato tale.
struct CheckmarkView: View {

    var size: CGFloat = 54
    var lineWidth: CGFloat = 2

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
                // Il cerchio parte da ore 12 invece che da ore 3.
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
        .onAppear {
            withAnimation(.easeOut(duration: 0.45)) {
                circleProgress = 1
            }
            // La spunta parte quando il cerchio è a metà: le due animazioni
            // si accavallano e il tutto sembra un gesto solo.
            withAnimation(.easeOut(duration: 0.35).delay(0.22)) {
                checkProgress = 1
            }
        }
    }
}

/// La forma della spunta, in coordinate relative al riquadro che la contiene.
struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height

        path.move(to: CGPoint(x: width * 0.04, y: height * 0.52))
        path.addLine(to: CGPoint(x: width * 0.38, y: height * 0.84))
        path.addLine(to: CGPoint(x: width * 0.96, y: height * 0.18))
        return path
    }
}
