import SwiftUI

/// Il pulviscolo luminoso sullo sfondo nero.
///
/// Puntini bianchi minuscoli, sparsi a caso ma sempre negli stessi punti — il
/// generatore ha un seme fisso, così lo sfondo non "salta" a ogni ridisegno —
/// che respirano lentamente cambiando opacità.
struct StarFieldView: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let stars = StarFieldView.makeStars(count: 46, seed: 0x5EED_1234)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate

                for star in StarFieldView.stars {
                    // Ogni puntino pulsa con la propria fase, così non
                    // lampeggiano tutti insieme come un albero di Natale.
                    let pulse = reduceMotion
                        ? 1.0
                        : 0.5 + 0.5 * sin(time * star.speed + star.phase)

                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: star.x * size.width,
                            y: star.y * size.height,
                            width: star.radius * 2,
                            height: star.radius * 2
                        )),
                        with: .color(.white.opacity(star.baseOpacity * (0.35 + 0.65 * pulse)))
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .blendMode(.plusLighter)
    }

    private struct Star {
        let x: CGFloat
        let y: CGFloat
        let radius: CGFloat
        let baseOpacity: Double
        let phase: Double
        let speed: Double
    }

    /// Generatore congruenziale lineare: nessuna dipendenza, e soprattutto
    /// risultati identici a ogni avvio.
    private static func makeStars(count: Int, seed: UInt64) -> [Star] {
        var state = seed
        func next() -> Double {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double((state >> 11) & 0xFFFF_FFFF) / Double(0xFFFF_FFFF)
        }

        return (0..<count).map { _ in
            Star(
                x: CGFloat(next()),
                y: CGFloat(next()),
                radius: CGFloat(0.6 + next() * 1.1),
                baseOpacity: 0.10 + next() * 0.30,
                phase: next() * .pi * 2,
                speed: 0.35 + next() * 0.7
            )
        }
    }
}
