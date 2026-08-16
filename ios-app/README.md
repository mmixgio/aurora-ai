# Cash

App iPhone nativa in SwiftUI che ricostruisce la sequenza di pagamento vista
nel video di riferimento: importo a tutto schermo su nero, conferma, Face ID,
la banconota che vola dentro l'avatar del destinatario e la spunta finale.

```
importo  →  conferma  →  Face ID  →  invio  →  fatto
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

> **I tasti del volume vanno provati su un iPhone vero.** Nel simulatore di
> Xcode non esistono tasti fisici del volume, quindi lì l'importo si regola
> solo con i pulsanti `−` e `+` a schermo.

---

## L'importo si regola con i tasti del volume

Niente tastierino. La cifra è già a schermo e si muove:

| Gesto | Effetto |
|---|---|
| Volume **su** | +1 € |
| Volume **giù** | −1 € |
| Tocco sui **centesimi** | i tasti passano al passo da 1 centesimo |
| Tocco sugli **euro** | si torna al passo da 1 € |
| Tasto **tenuto premuto** | il passo cresce: 1 → 2 → 5 → 10 |

L'accelerazione si azzera appena rallenti o cambi verso, così arrivi in fretta
sull'ordine di grandezza e poi aggiusti al centesimo. Una sottolineatura
scivola fra euro e centesimi per dire dove finirà la prossima pressione.

### Come funziona, e cosa può rompersi

iOS **non offre un'API pubblica** per leggere i tasti del volume. L'unica
eccezione è `AVCaptureEventInteraction`, che però vale solo mentre è attiva
una sessione della fotocamera.

`Services/VolumeButtonService.swift` usa quindi il meccanismo dei lettori
musicali e delle app di scatto remoto:

1. osserva `outputVolume` della sessione audio, che cambia a ogni pressione:
   dal segno del cambiamento si capisce quale tasto è stato premuto;
2. riporta subito il volume a metà, altrimenti arrivato al massimo o al minimo
   il tasto smetterebbe di produrre variazioni;
3. tiene un `MPVolumeView` fuori dallo schermo, che impedisce a iOS di
   mostrare il riquadro del volume a ogni tocco.

La sessione audio è `.ambient` con `.mixWithOthers`: se stai ascoltando
qualcosa non viene interrotto. Il volume di sistema viene rimesso com'era
quando esci dalla schermata.

Due limiti da conoscere. `MPVolumeView` è pubblico ma la sua gerarchia interna
non è documentata: se una versione futura di iOS la cambiasse, il servizio si
spegne invece di rompersi, `isListening` diventa `false` e la schermata lo
dice. Per questo i pulsanti `−` e `+` a schermo ci sono sempre — toglierli
significa perdere l'unica via di scampo. Sono in `AmountFieldView`, parametro
`showsControls`.

---

## Apple Pay e il doppio clic del tasto laterale

Il doppio clic del tasto di accensione **esiste in un solo posto**: dentro il
pannello di Apple Pay. Apple lo riserva a sé e non lo consegna a nessuna app,
quindi l'unico modo di averlo davvero è far comparire quel pannello.

L'app è pronta a farlo. `Services/ApplePayService.swift` usa **PassKit**, che è
l'equivalente nativo di Apple Pay JS: `PaymentRequest`, `onmerchantvalidation`
e `validateMerchant` girano dentro Safari, su un sito, e in un'app nativa non
esistono.

### Cosa serve per accenderlo

| | |
|---|---|
| **Apple Developer Program** | 99 €/anno. Con un Apple ID gratuito non si può creare un identificativo commerciante. |
| **Merchant ID** | Creato nel portale Apple, tipo `merchant.com.tuonome.cash`. Va messo in `ApplePay.merchantIdentifier`. |
| **Capacità Apple Pay** | In Xcode: target **Cash** → **Signing & Capabilities** → **+ Capability** → **Apple Pay**, poi spunta il merchant ID. |
| **Gestore dei pagamenti** | Stripe, Adyen, Nexi… è chi riceve il token che Apple restituisce. Senza, il pannello autorizza ma nessun soldo si muove. |

Le prime tre vanno insieme: la capacità Apple Pay genera un entitlement che la
firma gratuita non sa gestire, quindi aggiungerla senza account a pagamento fa
smettere di compilare il progetto. O tutte e tre, o nessuna.

C'è anche un vincolo di regolamento da sapere: **Apple Pay serve a pagare un
esercente**, non a mandare denaro a una persona. Un'app di pagamenti fra privati
non passerebbe la revisione — irrilevante per un'app installata solo sul proprio
telefono, ma è giusto averlo chiaro.

### Cosa fa l'app finché non lo accendi

`ApplePay.merchantIdentifier` è vuoto, quindi Apple Pay resta spento e la
schermata di conferma mostra il pulsante **Conferma pagamento** con il Face ID.
Funziona oggi, con un Apple ID gratuito, senza entitlement e senza gestore dei
pagamenti.

Appena metti un merchant ID valido e aggiungi la capacità, quel pulsante
diventa da solo il pulsante ufficiale di Apple Pay e la conferma passa dal suo
pannello — doppio clic del tasto laterale compreso. Se il pannello non riesce
ad aprirsi, l'app ripiega sul Face ID invece di lasciare il pagamento appeso.

---

---

## Cosa è vero e cosa è simulato

**Vero:** il Face ID (`LocalAuthentication` — senza autenticazione riuscita il
pagamento non parte), la rubrica (`Contacts`), la validazione IBAN
(ISO 13616, modulo 97), il salvataggio nel Portachiavi, i tasti del volume.

**Simulato:** il trasferimento di denaro. L'app registra l'IBAN e tiene la
contabilità, ma non è collegata a nessun circuito bancario — servirebbe un
istituto di pagamento autorizzato, con licenza, verifica dell'identità e
antiriciclaggio. Non è una riga di codice che manca.

---

## Com'è fatta

```
Cash/
├── App/              punto di ingresso, stato globale, Info.plist
├── Design/           colori, tipografia, testi, curve di animazione, vibrazioni
├── Models/           denaro, contatti, movimenti, conto, macchina a stati
├── Services/         Face ID, rubrica, tasti volume, Portachiavi, IBAN, salvataggio
└── Views/
    ├── Components/   banconota, importo, avatar, anello Face ID, spunta
    ├── Onboarding/   benvenuto, collegamento del conto
    ├── Home/         saldo, storico, denaro in entrata
    └── Pay/          la sequenza del pagamento
```

Il cuore è `Views/Pay/PaymentView.swift`: le cinque fasi vivono in un unico
`ZStack`, non in cinque schermate separate. È quello che permette alla
banconota di essere **un solo oggetto** che sale, si inclina, si rimpicciolisce
e sparisce dentro l'avatar. Con cinque schermate quel movimento continuo — che
è poi tutto il senso del design — non ci sarebbe.

Le animazioni stanno tutte in `Design/Motion.swift`, e sono molle e non durate
fisse: una molla decelera come farebbe un oggetto vero. Ogni tratto ha la sua
curva — `noteRise` è lenta e pesante perché la banconota deve sembrare che
entri in campo, `noteFly` è decisa e non rimbalza perché un rimbalzo, nel
momento in cui il denaro viene assorbito, sembrerebbe un errore.

---

## Personalizzare

| Cosa | Dove |
|---|---|
| Accendere Apple Pay | `ApplePay.merchantIdentifier` in `Services/ApplePayService.swift` |
| Valuta (`€`/`EUR` → `$`/`CAD` del video) | `AppConfiguration.currency` in `Models/Money.swift` |
| Velocità e rimbalzo di ogni animazione | `Design/Motion.swift` |
| Testi in italiano → inglese del video | `Copy.usesVideoWording` in `Design/Copy.swift` |
| Colori, font, misure | `Design/Theme.swift` |
| Accelerazione dei tasti volume | `PaymentFlow.multiplier(for:)` |
| Pulsanti `−` / `+` a schermo | `AmountFieldView`, parametro `showsControls` |
| Firma sulla banconota | dentro l'app, Profilo › Firma |
| Icona | `tools/make_app_icon.py` |

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
