import SwiftUI

/// Il linguaggio visivo dell'app, preso dal video di riferimento:
/// nero assoluto, testo bianco, nessun colore tranne il verde del Face ID.
///
/// Tutto quello che riguarda l'aspetto passa da qui: cambiare un valore in
/// questo file cambia l'app intera, senza dover cercare nelle singole schermate.
enum Theme {

    // MARK: - Colori

    /// Nero assoluto, non "quasi nero". Sui pannelli OLED dell'iPhone i pixel
    /// si spengono davvero e la banconota sembra sospesa nel vuoto, che è
    /// esattamente l'effetto del video.
    static let background = Color.black

    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.45)
    static let tertiaryText = Color.white.opacity(0.22)

    /// Bordi sottilissimi: si intuiscono più che vedersi.
    static let hairline = Color.white.opacity(0.10)

    /// Il verde dell'anello di autenticazione.
    static let faceID = Color(red: 0.29, green: 0.93, blue: 0.44)

    static let destructive = Color(red: 1.00, green: 0.27, blue: 0.23)

    /// La superficie della banconota: appena sopra il nero, così si stacca
    /// dallo sfondo senza sembrare un rettangolo grigio incollato sopra.
    static let noteSurface = Color(white: 0.055)
    static let noteSurfaceEdge = Color(white: 0.115)

    // MARK: - Gradienti

    /// L'effetto metallo delle cifre stampate sulla banconota.
    /// Le fasce chiare e scure alternate imitano la luce che scorre su una
    /// superficie in rilievo.
    static let metallic = LinearGradient(
        stops: [
            .init(color: Color(white: 0.99), location: 0.00),
            .init(color: Color(white: 0.68), location: 0.28),
            .init(color: Color(white: 0.97), location: 0.47),
            .init(color: Color(white: 0.58), location: 0.68),
            .init(color: Color(white: 0.90), location: 1.00)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// La luce diffusa sulla carta della banconota.
    static let noteSheen = LinearGradient(
        colors: [Color.white.opacity(0.06), Color.white.opacity(0.0), Color.white.opacity(0.03)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Tipografia

    /// L'importo gigante al centro dello schermo.
    static func amount(_ size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .default)
    }

    /// Le cifre in rilievo sulla banconota: più corpose e arrotondate.
    static func noteAmount(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    static let hint = Font.system(size: 15, weight: .semibold)
    static let title = Font.system(size: 28, weight: .semibold)
    static let body = Font.system(size: 16, weight: .regular)
    static let caption = Font.system(size: 13, weight: .regular)

    // MARK: - Misure

    /// Rapporto larghezza/altezza della banconota, ricalcato dal video.
    static let noteAspectRatio: CGFloat = 2.05
    static let noteCornerRadius: CGFloat = 18
    static let screenPadding: CGFloat = 28
}

extension View {
    /// Lo sfondo standard di ogni schermata: nero pieno fino ai bordi,
    /// con il campo di puntini luminosi che si intravede nel video.
    func cashBackground(showsStars: Bool = true) -> some View {
        self.background(
            ZStack {
                Theme.background
                if showsStars { StarFieldView() }
            }
            .ignoresSafeArea()
        )
    }
}
