import SwiftUI

/// Come la banconota è collocata nello spazio in un dato momento.
///
/// Un valore solo invece di cinque modificatori sparsi: la macchina a stati
/// dichiara *dove sta la banconota in questa fase*, e la vista lo applica.
/// È ciò che permette a una singola istanza di attraversare tutta la sequenza
/// invece di sparire e ricomparire.
struct BanknotePlacement: Equatable {

    /// Posizione del centro, in coordinate relative al contenitore (0…1).
    var unitPosition = CGPoint(x: 0.5, y: 0.5)
    var scale: CGFloat = 1
    var rotationDegrees: Double = 0
    var opacity: Double = 1

    /// Inclinazione prospettica attorno all'asse orizzontale, per il
    /// fluttuare della schermata di benvenuto.
    var tiltDegrees: Double = 0

    static let hidden = BanknotePlacement(
        unitPosition: CGPoint(x: 0.5, y: 1.32),
        scale: 0.88,
        opacity: 0
    )
}

/// La banconota.
///
/// Il denaro qui non è un numero in una lista: è un oggetto, con l'importo in
/// rilievo, la firma di chi lo manda e l'anno stampato. È quell'oggetto a
/// volare dentro l'avatar di chi riceve.
///
/// La faccia grafica è disegnata in codice (`BanknoteFace`) e vive in un tipo
/// separato apposta: se un giorno arriva un'illustrazione definitiva si
/// sostituisce quel tipo, e posizionamento, animazioni e chiamanti non
/// cambiano di una riga.
struct BanknoteView: View {

    let amount: Money
    let signature: String

    var width: CGFloat = 300
    var year: Int = Calendar.current.component(.year, from: Date())

    var body: some View {
        BanknoteFace(
            amount: amount,
            signature: signature,
            width: width,
            year: year
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Banconota")
        .accessibilityValue(amount.formattedExact())
    }
}

/// La faccia della banconota. Sostituibile in blocco.
private struct BanknoteFace: View {

    let amount: Money
    let signature: String
    let width: CGFloat
    let year: Int

    private var height: CGFloat { width / Theme.noteAspectRatio }

    /// Le scritte agli angoli scalano con la carta: su una versione piccola
    /// diventerebbero illeggibili, su una grande sembrerebbero dimenticate lì.
    private var scale: CGFloat { width / 300 }

    private var cornerRadius: CGFloat { Theme.noteCornerRadius * scale }

    var body: some View {
        ZStack {
            surface

            Text(amount.formatted())
                .font(Theme.engraved(58 * scale))
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .engraved()
                .padding(.horizontal, 28 * scale)
        }
        .frame(width: width, height: height)
        .overlay(alignment: .topLeading) { corner(Copy.noteKind, .topLeading) }
        .overlay(alignment: .topTrailing) { corner(AppConfiguration.currency.code, .topTrailing) }
        .overlay(alignment: .bottomLeading) { corner(signature, .bottomLeading) }
        .overlay(alignment: .bottomTrailing) { corner(String(year), .bottomTrailing) }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        // Un alone nero sotto la carta: la stacca dal fondo e le dà peso.
        .shadow(color: .black.opacity(0.85), radius: 24 * scale, y: 14 * scale)
    }

    /// Base scurissima, una luce morbida che entra da sinistra in alto, e un
    /// bordo di un pixel a definire il taglio.
    private var surface: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Theme.noteSurface)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [Theme.noteSurfaceEdge, .clear],
                            center: .init(x: 0.25, y: 0.15),
                            startRadius: 0,
                            endRadius: width * 0.85
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Theme.noteSheen)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            }
    }

    private func corner(_ text: String, _ alignment: Alignment) -> some View {
        Text(text)
            .font(.system(size: 9 * scale, weight: .semibold))
            .tracking(1.1 * scale)
            .foregroundStyle(Theme.secondaryText)
            .lineLimit(1)
            .padding(.horizontal, 16 * scale)
            .padding(.vertical, 14 * scale)
    }
}

// MARK: - Rilievo

private struct EngravedText: ViewModifier {
    func body(content: Content) -> some View {
        content
            // Tre copie sovrapposte: un'ombra scura spostata in basso e una
            // luce chiara spostata in alto creano il rilievo; la copia in
            // gradiente davanti dà il riflesso del metallo.
            .foregroundStyle(Theme.metallic)
            .background {
                content
                    .foregroundStyle(Color.black.opacity(0.75))
                    .offset(y: 1.5)
                    .blur(radius: 1.5)
            }
            .background {
                content
                    .foregroundStyle(Color.white.opacity(0.18))
                    .offset(y: -1)
                    .blur(radius: 0.8)
            }
    }
}

extension View {
    /// L'effetto "stampato in rilievo" delle cifre sulla banconota.
    func engraved() -> some View { modifier(EngravedText()) }

    /// Applica una collocazione dentro un contenitore di dimensione nota.
    func placed(_ placement: BanknotePlacement, in size: CGSize) -> some View {
        scaleEffect(placement.scale)
            .rotationEffect(.degrees(placement.rotationDegrees))
            .rotation3DEffect(
                .degrees(placement.tiltDegrees),
                axis: (x: 1, y: 0.6, z: 0),
                perspective: 0.6
            )
            .opacity(placement.opacity)
            .position(
                x: size.width * placement.unitPosition.x,
                y: size.height * placement.unitPosition.y
            )
    }
}
