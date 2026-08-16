import Foundation

/// Le attese della sequenza di pagamento, dietro un protocollo.
///
/// Serve a una cosa sola ma importante: i test della macchina a stati devono
/// poter attraversare l'intera sequenza in millisecondi invece di aspettare
/// davvero i 950 ms del volo della banconota.
protocol PaymentClock: Sendable {
    func sleep(_ duration: Duration) async
}

/// L'orologio vero.
struct SystemPaymentClock: PaymentClock {
    func sleep(_ duration: Duration) async {
        // L'annullamento non è un errore da propagare: se il compito viene
        // annullato la fase successiva non parte comunque, perché chi chiama
        // verifica `Task.isCancelled`.
        try? await Task.sleep(for: duration)
    }
}

/// L'orologio dei test: non aspetta niente.
struct ImmediatePaymentClock: PaymentClock {
    func sleep(_ duration: Duration) async {}
}
