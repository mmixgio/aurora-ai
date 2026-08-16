import SwiftUI

/// La home: quanto hai, la tua banconota, le due azioni possibili, lo storico.
///
/// È una `List` e non una `ScrollView` per una ragione precisa: lo scorrimento
/// laterale per eliminare un movimento è un gesto di sistema, e riprodurlo a
/// mano dentro una pila di rettangoli darebbe un'imitazione peggiore
/// dell'originale.
struct HomeView: View {

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 30) {
                        BalanceView(balance: appState.balance)

                        BanknoteView(
                            amount: appState.balance,
                            signature: appState.signature,
                            width: 300
                        )
                        .frame(maxWidth: .infinity)

                        actions
                    }
                    .padding(.vertical, 12)
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                HistoryListSection()
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .cashBackground()
            .navigationTitle("Cash")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        router.present(.settings)
                    } label: {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 18))
                            .foregroundStyle(Theme.primaryText)
                    }
                    .accessibilityLabel("Profilo")
                }
            }
        }
        .fullScreenCover(isPresented: $router.isPresentingPaymentFlow) {
            PaymentFlowView()
        }
        .sheet(item: $router.sheet) { sheet in
            switch sheet {
            case .requestMoney: RequestMoneyView()
            case .settings:     SettingsView()
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 12) {
            Button {
                router.startPayment()
            } label: {
                Label("Invia", systemImage: "arrow.up").frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())

            Button {
                router.present(.requestMoney)
            } label: {
                Label("Richiedi", systemImage: "arrow.down").frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }
}
