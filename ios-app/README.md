# Cash

App iPhone nativa in Swift + SwiftUI. Manda denaro a una persona: scegli chi,
regoli l'importo con i tasti del volume, confermi, ti autentichi col viso, e
guardi una banconota volare dentro il suo avatar.

```
importo  →  conferma  →  autenticazione  →  invio  →  fatto
```

**La contabilità è locale e simulata.** L'app non è collegata a nessun circuito
bancario, non fa richieste di rete, non ha account né analytics. Face ID,
rubrica, Portachiavi, validazione IBAN e tasti del volume sono invece reali.

- iOS 17+, Swift 5, **solo iPhone**, solo verticale, sempre in scuro.
- 57 file sorgente, 10 file di test, nessuna dipendenza esterna.

---

## Architettura

```
Cash/
├── App/            CashApp · AppState · AppRouter · RootView
├── Core/
│   ├── Models/     Money · Currency · ContactPerson · Transaction ·
│   │               BankAccount · PaymentDraft · PaymentPhase ·
│   │               AmountField · UserSignature
│   ├── Services/   Contacts · Biometric · VolumeButton · ApplePay ·
│   │               PaymentAuthorizer
│   ├── Persistence/ LocalStore · TransactionStore
│   ├── Security/   KeychainStore · IBANValidator
│   ├── Utilities/  SerialGenerator · StepAccelerator · DeterministicColor ·
│   │               PaymentClock · Haptics · SystemSettings
│   └── DesignSystem/ Theme · Motion · Copy
├── Features/       Onboarding · Home · Payment · Contacts · History · Settings
├── Components/     Banknote · Avatar · Buttons · Amount · Animations · States
└── Resources/      Assets.xcassets · Info.plist

CashTests/          9 suite + doppi di test
```

Il flusso delle dipendenze è a senso unico:

```
View  →  ViewModel  →  Service (protocollo)  →  framework Apple
```

Nessuna vista importa `Contacts`, `LocalAuthentication`, `AVFoundation`,
`Security` o `PassKit`. L'unica eccezione è `ApplePayButton`, che **è** per
definizione un ponte verso UIKit: il pulsante di Apple Pay dev'essere quello
vero, non una copia disegnata a mano.

Ogni servizio sta dietro un protocollo (`ContactsProviding`,
`BiometricAuthenticating`, `HardwareVolumeObserving`, `PaymentAuthorizing`,
`SecureStoring`, `LocalPersisting`, `PaymentClock`). È ciò che permette ai
test di attraversare l'intera sequenza di pagamento senza Face ID, senza
rubrica, senza disco e senza attese reali.

---

## Le tre decisioni che reggono tutto

### 1. Il saldo è derivato, non memorizzato

Viene salvato solo il **saldo di partenza**; quello corrente è sempre
`partenza + somma degli effetti dei movimenti`. Due verità separate — un saldo
su disco e uno storico accanto — prima o poi divergono dopo un salvataggio
interrotto. Con una fonte sola la coerenza è garantita dalla struttura, e
cancellare un movimento riporta il saldo esattamente a com'era.

### 2. Il commit arriva per ultimo

```
autenticazione riuscita  →  animazione (950 ms)  →  commit
```

Il movimento viene registrato **solo** dopo che entrambi sono andati a buon
fine, e il compito è annullabile: se la schermata si chiude a metà volo, in
contabilità non resta niente. È in `PaymentViewModel.send()`, sotto il
controllo su `Task.isCancelled`.

### 3. La banconota è un oggetto solo

Le cinque fasi vivono in un unico `ZStack`. Posizione, scala, rotazione e
opacità sono funzioni della fase (`BanknotePlacement`), e SwiftUI interpola il
resto. Con cinque schermate separate la banconota sparirebbe e riapparirebbe,
e tutto il senso del design se ne andrebbe.

Le animazioni sono **molle e non durate fisse** — una molla decelera come un
oggetto vero. Stanno tutte in `Core/DesignSystem/Motion.swift`.

| Curva | response | damping | Dove |
|---|---|---|---|
| `noteRise` | 0,95 | 0,84 | la banconota entra in campo: lenta, pesante |
| `noteFly` | 0,80 | 0,95 | assorbita dall'avatar: decisa, **zero rimbalzo** |
| `phase` | 0,60 | 0,86 | i cambi di fase |
| `value` | 0,28 | 0,80 | l'importo sotto i tasti |
| `detail` | 0,38 | 0,88 | sottolineature, avvisi |

---

## L'importo senza tastierino

| Gesto | Effetto |
|---|---|
| Volume **su** / **giù** | ±1 € |
| Tocco sui **centesimi** | passo da 1 centesimo |
| Tocco sugli **euro** | ritorno al passo da 1 € |
| Tasto **tenuto premuto** | 1 → 2 → 5 → 10 |

L'accelerazione si azzera dopo 0,45 s di pausa o al cambio di verso. Una
sottolineatura scivola fra euro e centesimi per dire dove finirà la prossima
pressione. Per VoiceOver è un unico controllo regolabile: scorrendo su e giù
l'importo si muove come con i tasti fisici.

### Come leggo i tasti, e cosa può rompersi

iOS **non espone i tasti del volume alle app**; l'unica eccezione,
`AVCaptureEventInteraction`, vale solo con la fotocamera attiva. Il servizio
osserva `outputVolume` della sessione audio, capisce dal segno quale tasto è
stato premuto, e riporta il volume a metà — altrimenti al massimo o al minimo
il tasto smetterebbe di produrre variazioni. Un `MPVolumeView` fuori schermo
sopprime il riquadro di sistema; la sessione è `.ambient` con `.mixWithOthers`
per non interrompere la musica, e il volume viene rimesso com'era all'uscita.

È un workaround, e per questo vive in **un solo file** dietro un protocollo.
La gerarchia interna di `MPVolumeView` non è documentata: se cambiasse,
`start()` lancia un errore tipizzato, l'app resta utilizzabile con i pulsanti
`−` e `+`, e la scritta diventa «Usa i pulsanti». Nel simulatore il servizio
si dichiara subito non disponibile invece di fingere.

---

## Apple Pay

`ApplePayConfiguration.merchantIdentifier` è vuoto, quindi Apple Pay è spento e
la conferma passa dall'autenticazione locale: funziona oggi, con un Apple ID
gratuito. Con un merchant ID valido il pulsante diventa da solo il
`PKPaymentButton` ufficiale e la conferma passa dal pannello di sistema —
**doppio clic del tasto laterale compreso**, che è l'unico posto in cui quel
gesto esiste per un'app di terze parti.

Per accenderlo servono, insieme: Apple Developer Program a pagamento, un
Merchant ID, la capacità Apple Pay sul target (l'entitlement non è gestibile
dalla firma gratuita) e un gestore dei pagamenti per il token. Apple Pay
**non** muove il saldo di questa app: autorizza, e la contabilità resta locale.

Il codice che circola con `PaymentRequest` e `onmerchantvalidation` è Apple Pay
**JS**, cioè Safari: in un'app nativa quelle classi non esistono.

---

## Test

```sh
xcodebuild test -scheme Cash -destination 'platform=iOS Simulator,name=iPhone 15'
```

o ⌘U in Xcode. Nove suite: `Money`, `IBANValidator`, `SerialGenerator`,
`DeterministicColor`, `StepAccelerator`, `TransactionStore`, `AppState`,
`PaymentStateMachine`, `TransactionFormatting`.

Coprono i casi limite che contano: saldo 0, importo 0, 5.000 € esatti,
5.000,01 €, saldo insufficiente, transazione duplicata, storico vuoto, storico
illeggibile, IBAN italiano valido e con checksum rotto, IBAN di paesi con
lunghezze da 15 a 31 caratteri, autenticazione annullata, commit rifiutato.

### Verifica senza Mac

`tools/verify_core_logic.py` riporta gli algoritmi puri in Python e ci fa
girare **gli stessi vettori** dei test Swift — 92 controlli su modulo 97,
aritmetica in centesimi, saturazione, accelerazione, saldo derivato e
normalizzazione della firma. Serve a validare la logica dove non c'è una
toolchain Swift; non sostituisce `xcodebuild test`, che va eseguito su un Mac.

---

## Installarla sul tuo iPhone

1. Apri `Cash.xcodeproj`.
2. Target **Cash** → **Signing & Capabilities** → metti il tuo Apple ID in **Team**.
3. Cambia il **Bundle Identifier** in qualcosa di tuo (`com.tuonome.Cash`).
4. Collega l'iPhone — **non il simulatore**, servono i tasti veri — e premi ⌘R.
5. Al primo avvio: **Impostazioni › Generali › VPN e gestione dispositivo** →
   tocca il tuo Apple ID → **Autorizza**.

Con un Apple ID gratuito la firma dura 7 giorni; con l'Apple Developer Program
(99 €/anno) un anno. Nessuna revisione di Apple in entrambi i casi.

---

## Privacy

Nessuna rete. Nessun server, nessuna API, nessun account, nessun analytics,
nessuna pubblicità, nessun tracciamento.

| Dato | Dove | Protezione |
|---|---|---|
| IBAN, intestatario | Portachiavi | `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` |
| Saldo, storico, firma | `UserDefaults` | non sensibili |
| Contatti | solo memoria | mai salvati |

Nessun `print` di dati personali, nessuna coordinata bancaria scritta nel
codice. Poiché il Portachiavi è `ThisDeviceOnly`, dopo un ripristino da backup
il conto va ricollegato: `AppState` lo rileva e rifà l'onboarding anche se le
preferenze dicono il contrario.

---

## Personalizzare

| Cosa | Dove |
|---|---|
| Accendere Apple Pay | `ApplePayConfiguration.merchantIdentifier` |
| Valuta, saldo iniziale, tetto, limiti | `AppConfiguration` in `Core/Models/Currency.swift` |
| Curve e tempi delle animazioni | `Core/DesignSystem/Motion.swift` |
| Colori, tipografia, misure | `Core/DesignSystem/Theme.swift` |
| Testi in italiano → inglese del video | `Copy.usesVideoWording` |
| Accelerazione dei tasti | `StepAccelerator.multiplier(forStreak:)` |
| Pulsanti `−` / `+` a schermo | `AmountView`, parametro `showsControls` |
| Icona | `tools/make_app_icon.py` |

---

## Strumenti

Il progetto Xcode è **generato**, non scritto a mano. Dopo aver aggiunto,
rinominato o spostato dei file:

```sh
python3 tools/generate_xcodeproj.py   # rigenera Cash.xcodeproj (app + test)
python3 tools/validate_project.py     # verifica riferimenti e file su disco
python3 tools/verify_core_logic.py    # riesegue i vettori dei test
python3 tools/make_app_icon.py        # ridisegna l'icona
```

Gli identificatori interni derivano dall'hash del percorso: rigenerando il
progetto non cambiano, e il diff su git resta leggibile.
