import Foundation

/// Il numero di serie stampato su ogni banconota.
///
/// Otto caratteri da un alfabeto che esclude `I`, `O`, `0` e `1`: letti a voce
/// o trascritti a mano quei quattro si confondono a coppie, e un seriale serve
/// proprio a essere riletto.
enum SerialGenerator {

    static let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
    static let length = 8

    /// I caratteri volutamente esclusi. Esposti perché sono un requisito, e
    /// un requisito senza test è solo un'intenzione.
    static let excludedCharacters: Set<Character> = ["I", "O", "0", "1"]

    static func make(using generator: () -> Int = { Int.random(in: 0..<SerialGenerator.alphabet.count) }) -> String {
        String((0..<length).map { _ in
            alphabet[min(max(generator(), 0), alphabet.count - 1)]
        })
    }

    /// Vero se la stringa ha forma di seriale: serve ai test e alla lettura
    /// di uno storico salvato da una versione precedente.
    static func isWellFormed(_ serial: String) -> Bool {
        serial.count == length && serial.allSatisfy(alphabet.contains)
    }
}
