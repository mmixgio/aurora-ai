import AVFoundation
import Foundation
import MediaPlayer
import UIKit

enum VolumeButtonDirection: Equatable, Sendable {
    case up
    case down
}

enum VolumeButtonError: Error, Equatable {
    /// Nel simulatore i tasti fisici non esistono.
    case unsupportedEnvironment
    case audioSessionUnavailable(String)
    /// Il cursore interno di `MPVolumeView` non è stato trovato: senza, il
    /// volume non può essere riportato al valore di ancoraggio e il
    /// meccanismo non funzionerebbe comunque.
    case volumeControlUnavailable

    var message: String {
        switch self {
        case .unsupportedEnvironment:
            return "I tasti del volume non esistono nel simulatore"
        case .audioSessionUnavailable(let why):
            return "Sessione audio non disponibile: \(why)"
        case .volumeControlUnavailable:
            return "Controllo del volume non accessibile su questa versione di iOS"
        }
    }
}

@MainActor
protocol HardwareVolumeObserving: AnyObject {
    var isListening: Bool { get }
    func start(onPress: @escaping (VolumeButtonDirection) -> Void) throws
    func stop()
}

/// Trasforma i tasti del volume in due pulsanti "più" e "meno".
///
/// ## Perché è un workaround, e perché è isolato qui dentro
///
/// iOS **non** espone i tasti del volume alle app. L'unica eccezione,
/// `AVCaptureEventInteraction`, funziona solo mentre è attiva una sessione
/// della fotocamera. La tecnica usata qui è quella dei lettori musicali:
///
/// 1. si osserva `outputVolume` della sessione audio: cambia a ogni
///    pressione, e dal segno si capisce quale tasto;
/// 2. si riporta subito il volume al valore di ancoraggio, altrimenti al
///    massimo o al minimo il tasto smetterebbe di produrre variazioni;
/// 3. un `MPVolumeView` fuori dallo schermo impedisce a iOS di mostrare il
///    riquadro del volume a ogni tocco.
///
/// La gerarchia interna di `MPVolumeView` non è documentata. Se una versione
/// futura di iOS la cambiasse, `start` lancia e l'app passa ai controlli a
/// schermo: **nessun crash, nessuna schermata bloccata**. È l'unica ragione
/// per cui tutto questo vive dietro un protocollo, in un file solo, e non
/// sparso dentro le viste.
@MainActor
final class VolumeButtonService: HardwareVolumeObserving {

    /// Il valore a cui il volume viene continuamente riportato: lontano da 0
    /// e da 1, altrimenti in un verso non resterebbe margine di manovra.
    private let anchor: Float = 0.5

    /// Lo scatto del volume su iOS è 1/16 = 0,0625. La soglia sta sotto, ma
    /// abbastanza sopra lo zero da ignorare gli arrotondamenti.
    private let threshold: Float = 0.01

    /// Quanto resta alzata la guardia dopo una nostra correzione. Sotto
    /// questo tempo l'eco del riposizionamento verrebbe scambiata per una
    /// nuova pressione e i due si rincorrerebbero.
    private let restoreGuard: TimeInterval = 0.18

    private(set) var isListening = false

    private let session = AVAudioSession.sharedInstance()
    private var observation: NSKeyValueObservation?
    private var volumeView: MPVolumeView?
    private var volumeBeforeStart: Float?
    private var isRestoring = false
    private var onPress: ((VolumeButtonDirection) -> Void)?

    func start(onPress: @escaping (VolumeButtonDirection) -> Void) throws {
        guard !isListening else { return }

        #if targetEnvironment(simulator)
        // Nel simulatore non c'è nulla da osservare: meglio dirlo subito e
        // lasciare che l'interfaccia mostri i controlli a schermo.
        throw VolumeButtonError.unsupportedEnvironment
        #else

        try attachVolumeView()

        do {
            // `.ambient` con `.mixWithOthers` non interrompe la musica di chi
            // sta ascoltando: all'app serve solo poter leggere il volume.
            try session.setCategory(.ambient, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            detachVolumeView()
            throw VolumeButtonError.audioSessionUnavailable(error.localizedDescription)
        }

        self.onPress = onPress
        volumeBeforeStart = session.outputVolume
        setSystemVolume(anchor)

        observation = session.observe(\.outputVolume, options: [.new]) { [weak self] _, change in
            guard let value = change.newValue else { return }
            Task { @MainActor [weak self] in
                self?.handle(volume: value)
            }
        }

        isListening = true
        #endif
    }

    func stop() {
        guard isListening else { return }

        observation?.invalidate()
        observation = nil
        onPress = nil

        // Il volume torna com'era: l'app lo ha preso in prestito.
        if let original = volumeBeforeStart {
            setSystemVolume(original)
            volumeBeforeStart = nil
        }

        detachVolumeView()

        // Disattivare la sessione può fallire se qualcun altro la sta usando.
        // Non è una condizione su cui l'utente possa fare qualcosa, e non
        // impedisce di uscire dalla schermata.
        do {
            try session.setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            assertionFailure("Sessione audio non disattivata: \(error.localizedDescription)")
        }

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
    /// Quel cursore è un `MPVolumeSlider`: assegnargli un valore cambia il
    /// volume davvero. `MPVolumeView` è API pubblica; la sua gerarchia interna
    /// no, quindi l'assenza del cursore è un caso previsto e non un crash.
    private func setSystemVolume(_ value: Float) {
        guard let slider = volumeSlider else { return }

        isRestoring = true
        slider.value = value
        slider.sendActions(for: .valueChanged)

        Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: UInt64(self.restoreGuard * 1_000_000_000))
            self.isRestoring = false
        }
    }

    private var volumeSlider: UISlider? {
        volumeView?.subviews.compactMap { $0 as? UISlider }.first
    }

    /// Aggiunge il `MPVolumeView` alla finestra, fuori dallo schermo.
    ///
    /// Deve essere presente e non nascosto perché iOS smetta di disegnare il
    /// riquadro del volume; le coordinate negative lo rendono invisibile senza
    /// renderlo `hidden`.
    private func attachVolumeView() throws {
        guard volumeView == nil else { return }

        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }

        guard let window else {
            throw VolumeButtonError.volumeControlUnavailable
        }

        let view = MPVolumeView(frame: CGRect(x: -4000, y: -4000, width: 1, height: 1))
        view.alpha = 0.001
        view.isUserInteractionEnabled = false
        window.addSubview(view)
        volumeView = view

        guard volumeSlider != nil else {
            detachVolumeView()
            throw VolumeButtonError.volumeControlUnavailable
        }
    }

    private func detachVolumeView() {
        volumeView?.removeFromSuperview()
        volumeView = nil
    }
}
