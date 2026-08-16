import Foundation

/// Una persona a cui si può inviare denaro.
///
/// Si chiama `ContactPerson` e non `Contact` per non collidere con `CNContact`
/// né con il nome del framework: dentro le viste deve essere ovvio che si sta
/// maneggiando un modello dell'app, non un oggetto di sistema.
///
/// È un valore puro: non contiene riferimenti al framework Contacts, così la
/// logica che lo usa resta testabile senza rubrica.
struct ContactPerson: Identifiable, Hashable, Sendable {

    /// L'identificatore assegnato da iOS al contatto in rubrica.
    let id: String
    let givenName: String
    let familyName: String
    let organizationName: String

    /// La miniatura della foto profilo, se presente.
    let imageData: Data?

    init(
        id: String,
        givenName: String = "",
        familyName: String = "",
        organizationName: String = "",
        imageData: Data? = nil
    ) {
        self.id = id
        self.givenName = givenName
        self.familyName = familyName
        self.organizationName = organizationName
        self.imageData = imageData
    }

    /// Il nome sotto l'avatar: il nome di battesimo basta e occupa poco.
    var displayName: String {
        if !givenName.isEmpty { return givenName }
        if !familyName.isEmpty { return familyName }
        if !organizationName.isEmpty { return organizationName }
        return "Sconosciuto"
    }

    /// Nome completo, usato nella lista e congelato nello storico.
    var fullName: String {
        let joined = [givenName, familyName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return joined.isEmpty ? displayName : joined
    }

    /// Le iniziali disegnate nel cerchio quando manca la foto.
    var initials: String {
        ContactPerson.initials(for: fullName)
    }

    /// Una scheda senza alcun dato utile non ha niente da mostrare in lista.
    var isPresentable: Bool {
        !givenName.isEmpty || !familyName.isEmpty || !organizationName.isEmpty
    }

    /// Estrae le iniziali da un nome qualsiasi.
    ///
    /// Statica perché serve anche allo storico, dove del contatto resta solo
    /// il nome congelato e non c'è più una scheda da cui ricavarle.
    static func initials(for name: String) -> String {
        let letters = name
            .split(separator: " ")
            .compactMap(\.first)
            .prefix(2)

        guard !letters.isEmpty else { return "?" }
        return String(letters).uppercased()
    }
}
