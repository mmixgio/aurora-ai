import SwiftUI

/// Il linguaggio visivo dell'app: nero assoluto, testo bianco, nessun colore
/// tranne il verde dell'autenticazione e il rosso degli errori.
///
/// Tutto ciò che riguarda l'aspetto passa da qui. Cambiare un valore in questo
/// file cambia l'app intera, senza cercare nelle singole viste.
enum Theme {

    // MARK: - Colori

    /// Nero assoluto, non "quasi nero": sui pannelli OLED i pixel si spengono
    /// davvero e la banconota sembra sospesa nel vuoto.
    static let background = Color.black

    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.45)
    static let tertiaryText = Color.white.opacity(0.22)

    /// Bordi sottilissimi: si intuiscono più che vedersi.
    static let hairline = Color.white.opacity(0.10)

    /// Superfici appena sopra il nero, per le poche zone che devono staccarsi.
    static let surface = Color.white.opacity(0.035)
    static let surfaceRaised = Color.white.opacity(0.06)

    static let authentication = Color(red: 0.29, green: 0.93, blue: 0.44)
    static let destructive = Color(red: 1.00, green: 0.27, blue: 0.23)
    static let positive = Color(red: 0.29, green: 0.93, blue: 0.44)

    /// La carta della banconota.
    static let noteSurface = Color(white: 0.055)
    static let noteSurfaceEdge = Color(white: 0.115)

    // MARK: - Gradienti

    /// L'effetto metallo delle cifre in rilievo: fasce chiare e scure
    /// alternate imitano la luce che scorre su una superficie incisa.
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

    static let noteSheen = LinearGradient(
        colors: [.white.opacity(0.06), .white.opacity(0.0), .white.opacity(0.03)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Tipografia
    //
    // I testi di lettura usano gli stili di sistema e quindi **seguono
    // Dynamic Type**: chi ha impostato caratteri grandi li vede grandi anche
    // qui. Le cifre da esposizione restano a corpo fisso perché sono un
    // elemento grafico, ma vengono scalate con `@ScaledMetric` dove serve e
    // hanno sempre `minimumScaleFactor`.

    static let title = Font.system(.title, design: .default, weight: .semibold)
    static let headline = Font.system(.title3, design: .default, weight: .semibold)
    static let body = Font.system(.body)
    static let bodyEmphasis = Font.system(.body, design: .default, weight: .medium)
    static let caption = Font.system(.footnote)
    static let micro = Font.system(.caption2)

    /// Etichette in maiuscoletto spaziato: sezioni, angoli della banconota.
    static let label = Font.system(.caption2, design: .default, weight: .semibold)

    /// L'importo a tutto schermo.
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .default)
    }

    /// Le cifre in rilievo sulla banconota: più corpose e arrotondate.
    static func engraved(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    // MARK: - Misure

    /// Rapporto larghezza/altezza della banconota.
    static let noteAspectRatio: CGFloat = 2.05
    static let noteCornerRadius: CGFloat = 18
    static let screenPadding: CGFloat = 28
    static let cardCornerRadius: CGFloat = 18
    static let controlHeight: CGFloat = 54
}

extension View {
    /// Lo sfondo standard di ogni schermata.
    func cashBackground(showsStars: Bool = true) -> some View {
        background(
            ZStack {
                Theme.background
                if showsStars { StarFieldView() }
            }
            .ignoresSafeArea()
        )
    }
}
