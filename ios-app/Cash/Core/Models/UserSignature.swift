import Foundation

/// La firma stampata in basso a sinistra sulla banconota.
///
/// Regole: sempre una sola chiocciola davanti, sempre maiuscolo, solo
/// caratteri che stanno bene stampati. "Giovanni" diventa "@GIOVANNI",
/// "@@gio vanni!" diventa "@GIOVANNI".
enum UserSignature {

    static let fallback = "@ME"

    /// Quanti caratteri stanno nell'angolo della banconota senza sfondare.
    static let maximumLength = 16

    static func normalize(_ raw: String) -> String {
        let kept = raw.uppercased().filter {
            $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_")
        }
        let text = String(kept.prefix(maximumLength))
        return text.isEmpty ? fallback : "@" + text
    }
}
