import SwiftUI

/// La banconota: il pezzo forte del video.
///
/// L'idea che regge tutto il design è che il denaro qui non sia un numero in
/// una lista, ma un **oggetto**: una carta scura con l'importo in rilievo,
/// il tuo nome stampato in un angolo e l'anno nell'altro. È l'oggetto che
/// poi vola dentro l'avatar di chi lo riceve.
struct BanknoteView: View {

    let amount: Money
    /// La firma in basso a sinistra (`@BENGIANNIS` nel video).
    let handle: String

    /// Larghezza della banconota; l'altezza segue il rapporto del video.
    var width: CGFloat = 300

    /// L'anno stampato in basso a destra.
    var year: Int = Calendar.current.component(.year, from: Date())

    private var height: CGFloat { width / Theme.noteAspectRatio }

    /// Le scritte agli angoli scalano insieme alla banconota, altrimenti su
    /// una versione piccola diventano illeggibili e su una grande sembrano
    /// dimenticate lì.
    private var scale: CGFloat { width / 300 }

    var body: some View {
        ZStack {
            surface

            Text(amount.formatted())
                .font(Theme.noteAmount(58 * scale))
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .embossed()
                .padding(.horizontal, 28 * scale)
        }
        .frame(width: width, height: height)
        .overlay(alignment: .topLeading) {
            cornerLabel(Copy.noteKind)
                .padding(.leading, 16 * scale)
                .padding(.top, 14 * scale)
        }
        .overlay(alignment: .topTrailing) {
            cornerLabel(AppConfiguration.currency.code)
                .padding(.trailing, 16 * scale)
                .padding(.top, 14 * scale)
        }
        .overlay(alignment: .bottomLeading) {
            cornerLabel(handle)
                .padding(.leading, 16 * scale)
                .padding(.bottom, 14 * scale)
        }
        .overlay(alignment: .bottomTrailing) {
            cornerLabel(String(year))
                .padding(.trailing, 16 * scale)
                .padding(.bottom, 14 * scale)
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.noteCornerRadius * scale, style: .continuous))
        // Un alone nero sotto la carta: la stacca dal fondo e le dà peso.
        .shadow(color: .black.opacity(0.85), radius: 24 * scale, x: 0, y: 14 * scale)
    }

    // MARK: - Pezzi

    /// La superficie della carta: base scurissima, una luce morbida che entra
    /// da sinistra in alto e un bordo di un solo pixel per definire il taglio.
    private var surface: some View {
        RoundedRectangle(cornerRadius: Theme.noteCornerRadius * scale, style: .continuous)
            .fill(Theme.noteSurface)
            .overlay {
                RoundedRectangle(cornerRadius: Theme.noteCornerRadius * scale, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [Theme.noteSurfaceEdge, Color.clear],
                            center: .init(x: 0.25, y: 0.15),
                            startRadius: 0,
                            endRadius: width * 0.85
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: Theme.noteCornerRadius * scale, style: .continuous)
                    .fill(Theme.noteSheen)
            }
            .overlay {
                RoundedRectangle(cornerRadius: Theme.noteCornerRadius * scale, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            }
    }

    private func cornerLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9 * scale, weight: .semibold))
            .tracking(1.1 * scale)
            .foregroundStyle(Theme.secondaryText)
            .lineLimit(1)
    }
}

// MARK: - Testo in rilievo

private struct EmbossedText: ViewModifier {
    func body(content: Content) -> some View {
        content
            // Tre copie sovrapposte: un'ombra scura spostata in basso e una
            // luce chiara spostata in alto creano il rilievo, la copia in
            // gradiente sopra dà il riflesso del metallo.
            .foregroundStyle(Theme.metallic)
            .background {
                content
                    .foregroundStyle(Color.black.opacity(0.75))
                    .offset(x: 0, y: 1.5)
                    .blur(radius: 1.5)
            }
            .background {
                content
                    .foregroundStyle(Color.white.opacity(0.18))
                    .offset(x: 0, y: -1)
                    .blur(radius: 0.8)
            }
    }
}

extension View {
    /// L'effetto "stampato in rilievo" delle cifre sulla banconota.
    func embossed() -> some View {
        modifier(EmbossedText())
    }
}

#Preview {
    ZStack {
        Color.black
        BanknoteView(amount: Money(units: 20), handle: "@BENGIANNIS", width: 320)
    }
    .ignoresSafeArea()
}
