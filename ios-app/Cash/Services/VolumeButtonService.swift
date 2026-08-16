import AVFoundation
import MediaPlayer
import SwiftUI
import UIKit

/// Trasforma i tasti del volume in due pulsanti "più" e "meno".
///
/// Va detto com'è: iOS **non offre un'API pubblica** per leggere i tasti del
/// volume. L'unica eccezione è `AVCaptureEventInteraction`, che però funziona
/// soltanto mentre è attiva una sessione della fotocamera.
///
/// Il meccanismo usato qui è quello dei lettori musicali e delle app di
/// scatto remoto, ed è composto di due pezzi:
///
/// 1. si osserva `outputVolume` della sessione audio, che cambia quando
///    l'utente preme un tasto: dal segno del cambiamento si capisce quale;
/// 2. si riporta subito il volume al valore di partenza, altrimenti arrivato
///    al massimo o al minimo il tasto smetterebbe di produrre variazioni.
///
/// Un `MPVolumeView` fuori dallo schermo serve a impedire che iOS mostri il
/// riquadro del volume a ogni pressione.
///
/// Limiti da conoscere: la struttura interna di `MPVolumeView` non è
/// documentata e potrebbe cambiare in una versione futura di iOS; e il
/// volume dell'utente viene toccato (viene rimesso com'era quando la
/// schermata si chiude). Per questo l'importo si può sempre regolare anche
/// con i pulsanti a schermo.
@MainActor
final class VolumeButtonService: ObservableObject {

    enum Direction {
        case up
        case down
    }

    /// Chiamata a ogni pressione. Assegnala prima di `start()`.
    var onPress: ((Direction) -> Void)?

    /// `false` se il meccanismo non è riuscito ad attivarsi: la schermata può
    /// mostrare un avviso invece di lasciare l'utente a premere a vuoto.
    @Published private(set) var isListening = false

    /// Il valore a cui il volume viene continuamente riportato. Deve stare
    /// lontano da 0 e da 1, altrimenti in un verso non ci sarebbe margine.
    private let anchor: Float = 0.5

    /// Lo scatto del volume su iOS è 1/16. La soglia sta sotto, ma abbastanza
    /// sopra lo zero da ignorare gli assestamenti dovuti agli arrotondamenti.
    private let threshold: Float = 0.01

    private let session = AVAudioSession.sharedInstance()
    private var observation: NSKeyValueObservation?
    private var volumeView: MPVolumeView?
    private var volumeBeforeStart: Float?

    /// Alza la guardia mentre siamo noi a rimettere a posto il volume: senza,
    /// ogni correzione verrebbe letta come una nuova pressione e i due si
    /// rincorrerebbero all'infinito.
    private var isRestoring = false

    // MARK: - Avvio e arresto

    func start() {
        guard !isListening else { return }

        attachVolumeView()

        do {
            // `.ambient` con `.mixWithOthers` non interrompe la musica di chi
            // sta ascoltando qualcosa: l'app deve solo poter leggere il volume.
            try session.setCategory(.ambient, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            isListening = false
            return
        }

        volumeBeforeStart = session.outputVolume
        setSystemVolume(anchor)

        observation = session.observe(\.outputVolume, options: [.new]) { [weak self] _, change in
            guard let value = change.newValue else { return }
            Task { @MainActor [weak self] in
                self?.handle(volume: value)
            }
        }

        isListening = true
    }

    func stop() {
        guard isListening else { return }

        observation?.invalidate()
        observation = nil

        // Il volume torna com'era prima: l'app lo ha preso in prestito.
        if let original = volumeBeforeStart {
            setSystemVolume(original)
            volumeBeforeStart = nil
        }

        volumeView?.removeFromSuperview()
        volumeView = nil

        try? session.setActive(false, options: [.notifyOthersOnDeactivation])
        isListening = false
    }

    // MARK: - Lettura

    private func handle(volume: Float) {
        guard isListening, !isRestoring else { return }

        if volume > anchor + threshold {
            onPress?(.up)
        } else if volume < anchor - threshold {
            onPress?(.down)
        } else {
            return
        }

        setSystemVolume(anchor)
    }

    // MARK: - Scrittura

    /// Muove il volume di sistema agendo sul cursore dentro `MPVolumeView`.
    ///
    /// Quel cursore è un `MPVolumeSlider`: assegnargli un valore fa cambiare
    /// il volume davvero. Non è una API privata — `MPVolumeView` è pubblico —
    /// ma la sua gerarchia interna non è documentata, quindi se un giorno non
    /// trovasse più il cursore l'app deve semplicemente non fare nulla.
    private func setSystemVolume(_ value: Float) {
        guard let slider = volumeView?.subviews.compactMap({ $0 as? UISlider }).first else {
            return
        }

        isRestoring = true
        slider.value = value
        slider.sendActions(for: .valueChanged)

        // Il cambio di volume viene notificato in modo asincrono: la guardia
        // resta alzata quel tanto che basta perché l'eco della nostra
        // correzione non venga scambiata per una pressione.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
            self?.isRestoring = false
        }
    }

    /// Aggiunge il `MPVolumeView` alla finestra, fuori dallo schermo.
    ///
    /// Deve essere presente e non nascosto perché iOS smetta di disegnare il
    /// riquadro del volume; spostarlo a coordinate negative lo rende
    /// invisibile senza renderlo "hidden".
    private func attachVolumeView() {
        guard volumeView == nil else { return }

        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }

        guard let window else { return }

        let view = MPVolumeView(frame: CGRect(x: -4000, y: -4000, width: 1, height: 1))
        view.alpha = 0.001
        view.isUserInteractionEnabled = false
        window.addSubview(view)

        volumeView = view
    }
}
