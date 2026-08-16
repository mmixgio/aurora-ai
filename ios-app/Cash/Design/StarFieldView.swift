import SwiftUI

/// Il pulviscolo luminoso che si vede sullo sfondo nero nei frame del video.
///
/// Sono puntini bianchi minuscoli, sparsi a caso ma sempre negli stessi punti
/// (il generatore ha un seme fisso, così lo sfondo non "salta" a ogni ridisegno)
/// che respirano lentamente cambiando opacità.
struct StarFieldView: View {

    /// Posizioni in coordinate relative (0…1) più fase e velocità del respiro.
    private let stars: [Star] = StarFieldView.makeStars(count: 46, seed: 0x5EED_1234)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate

                for star in stars {
                    // Ogni puntino pulsa con la sua fase, così non lampeggiano
                    // tutti insieme come un albero di Natale.
                    let pulse = 0.5 + 0.5 * sin(t * star.speed + star.phase)
                    let opacity = star.baseOpacity * (0.35 + 0.65 * pulse)

                    let rect = CGRect(
                        x: star.x * size.width,
                        y: star.y * size.height,
                        width: star.radius * 2,
                        height: star.radius * 2
                    )

                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(.white.opacity(opacity))
                    )
                }
            }
        }
        .allowsHitTesting(false)
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

    /// Generatore congruenziale lineare: due righe di codice, nessuna
    /// dipendenza, e soprattutto risultati identici a ogni avvio.
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
