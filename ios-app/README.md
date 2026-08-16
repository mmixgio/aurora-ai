# Cash

App iPhone nativa in SwiftUI che ricostruisce la sequenza di pagamento vista
nel video di riferimento: importo a tutto schermo su nero, il gesto di
conferma, il Face ID, la banconota che vola dentro l'avatar del destinatario
e la spunta finale.

```
importo  →  armato  →  Face ID  →  invio  →  fatto
```

- **Solo iPhone**, solo verticale, sempre in scuro (`TARGETED_DEVICE_FAMILY = 1`).
- **Nessun account, nessun server**: saldo e storico stanno sul telefono,
  le coordinate bancarie nel Portachiavi.
- **iOS 17.0** o successivo, Swift 5.

---

## Aprirla e installarla sul tuo iPhone

Serve un Mac con Xcode. Non serve l'iscrizione all'Apple Developer Program:
con un Apple ID normale l'app si installa lo stesso, va solo rifirmata ogni
7 giorni.

1. Apri `Cash.xcodeproj`.
2. Seleziona il target **Cash** → scheda **Signing & Capabilities**.
3. Metti il tuo Apple ID in **Team** (Xcode → Settings → Accounts se non c'è).
4. Cambia il **Bundle Identifier** in qualcosa di tuo, per esempio
   `com.tuonome.Cash`: quello di default potrebbe risultare già preso.
5. Collega l'iPhone, selezionalo come destinazione e premi ⌘R.
6. Al primo avvio l'iPhone rifiuta l'app: vai in
   **Impostazioni › Generali › VPN e gestione dispositivo**, tocca il tuo
   Apple ID e scegli **Autorizza**.

Con l'Apple Developer Program (99 €/anno) la firma dura un anno invece di
sette giorni. Per un uso personale non serve nient'altro: niente revisione
di Apple, niente App Store.

---

## Due cose da sapere

### Il doppio clic del tasto laterale non è replicabile

Nel video la conferma è il doppio clic del tasto di accensione. Quel gesto è
riservato da Apple ad Apple Pay: iOS non lo espone a nessuna app di terze
parti, e non è una restrizione dell'App Store che si aggiri installando da
Xcode — l'evento proprio non arriva all'app.

L'unico modo di vedere davvero quel doppio clic è integrare **Apple Pay**
tramite PassKit, che però richiede un merchant ID e un gestore di pagamenti
registrato, e serve a pagare un esercente, non una persona.

Qui la conferma è quindi un **doppio tocco sullo schermo**, con la stessa
scritta e la stessa posizione del video. È un solo punto del codice, in
`Views/Pay/PaymentView.swift`:

```swift
.onTapGesture(count: 2) {
    Task { await flow.confirm() }
}
```

Chi ha un iPhone 15 Pro o successivo può in più assegnare il **tasto Azione**
a un Comando rapido che apre l'app.

### Il denaro non si sposta davvero

L'app registra l'IBAN, valida le coordinate e tiene la contabilità, ma non è
collegata a nessun circuito bancario: spostare denaro vero richiede un
istituto di pagamento autorizzato dietro. Saldo e movimenti sono una
simulazione locale.

Quello che invece è **reale**: il Face ID (framework `LocalAuthentication` —
senza autenticazione riuscita il pagamento non parte), la rubrica
(framework `Contacts`), la validazione IBAN (ISO 13616, modulo 97) e il
salvataggio nel Portachiavi.

---

## Com'è fatta

```
Cash/
├── App/              punto di ingresso, stato globale, Info.plist
├── Design/           colori, tipografia, testi, vibrazioni, pulviscolo di sfondo
├── Models/           denaro, contatti, movimenti, conto, macchina a stati
├── Services/         Face ID, rubrica, Portachiavi, IBAN, salvataggio
└── Views/
    ├── Components/   banconota, avatar, anello Face ID, spunta, tastierino
    ├── Onboarding/   benvenuto, collegamento del conto
    ├── Home/         saldo, storico, denaro in entrata
    └── Pay/          la sequenza del video
```

Il cuore è `Views/Pay/PaymentView.swift`: le cinque fasi vivono in un unico
`ZStack`, non in cinque schermate separate. È quello che permette alla
banconota di essere **un solo oggetto** che si sposta, rimpicciolisce e
sparisce dentro l'avatar. Con cinque schermate quel movimento continuo — che
è poi tutto il senso del design — non ci sarebbe.

---

## Personalizzare

| Cosa | Dove |
|---|---|
| Valuta (`$`/`CAD` → `€`/`EUR`) | `AppConfiguration.currency` in `Models/Money.swift` |
| Testi inglesi del video → italiano | `Copy.usesVideoWording` in `Design/Copy.swift` |
| Colori, font, misure | `Design/Theme.swift` |
| Firma sulla banconota | dentro l'app, Profilo › Firma |
| Inclinazione e colori dell'icona | `tools/make_app_icon.py` |

---

## Strumenti

Il progetto Xcode è generato, non scritto a mano. Dopo aver aggiunto o
rinominato dei file:

```sh
python3 tools/generate_xcodeproj.py   # rigenera Cash.xcodeproj
python3 tools/validate_project.py     # controlla che sia coerente
python3 tools/make_app_icon.py        # ridisegna l'icona
```

Gli identificatori interni derivano dall'hash del percorso, quindi
rigenerando il progetto non cambiano e il diff su git resta leggibile.
