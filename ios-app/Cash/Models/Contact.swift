import Foundation

/// Una persona a cui puoi mandare denaro, letta dalla rubrica dell'iPhone.
struct Contact: Identifiable, Hashable {
    /// L'identificatore assegnato da iOS al contatto in rubrica.
    let id: String
    let givenName: String
    let familyName: String
    let organizationName: String

    /// La miniatura della foto profilo, se il contatto ne ha una.
    let imageData: Data?

    /// Il nome mostrato sotto l'avatar. Nel video è solo "Natalie": il nome
    /// di battesimo basta e occupa poco, il cognome si aggiunge solo se
    /// altrimenti non ci sarebbe nulla da mostrare.
    var displayName: String {
        if !givenName.isEmpty { return givenName }
        if !familyName.isEmpty { return familyName }
        if !organizationName.isEmpty { return organizationName }
        return "Sconosciuto"
    }

    /// Nome completo, usato nella lista e nello storico.
    var fullName: String {
        let joined = [givenName, familyName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return joined.isEmpty ? displayName : joined
    }

    /// Le iniziali disegnate nel cerchio quando manca la foto.
    var initials: String {
        let letters = [givenName, familyName]
            .filter { !$0.isEmpty }
            .compactMap { $0.first }
            .prefix(2)

        if letters.isEmpty {
            return String(displayName.prefix(1)).uppercased()
        }
        return String(letters).uppercased()
    }

    /// La lettera sotto cui il contatto finisce nella lista alfabetica.
    var sectionKey: String {
        let source = familyName.isEmpty ? displayName : familyName
        guard let first = source.first, first.isLetter else { return "#" }
        return String(first).uppercased()
    }
}
