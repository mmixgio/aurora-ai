import SwiftUI

/// La home: quanto hai, la tua banconota, e le due sole azioni possibili.
struct HomeView: View {

    @EnvironmentObject private var appState: AppState
    @State private var showsPayFlow = false
    @State private var showsSettings = false
    @State private var showsRequest = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 34) {
                    balanceSection
                    noteSection
                    actionsSection
                    ActivityListView()
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 48)
            }
            .frame(maxWidth: .infinity)
            .cashBackground()
            .navigationTitle("Cash")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showsSettings = true
                    } label: {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 18))
                            .foregroundStyle(Theme.primaryText)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showsPayFlow) {
            PayFlowContainer()
        }
        .sheet(isPresented: $showsSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showsRequest) {
            RequestMoneyView()
        }
    }

    // MARK: - Sezioni

    private var balanceSection: some View {
        VStack(spacing: 6) {
            Text("Saldo disponibile")
                .font(.system(size: 13))
                .foregroundStyle(Theme.secondaryText)

            Text(appState.balance.formatted())
                .font(Theme.amount(52))
                .foregroundStyle(Theme.primaryText)
                // Fa scorrere le cifre invece di sostituirle di colpo quando
                // il saldo cambia dopo un pagamento.
                .contentTransition(.numericText())
                .animation(Motion.phase, value: appState.balance)
        }
        .padding(.top, 12)
    }

    private var noteSection: some View {
        BanknoteView(
            amount: appState.balance,
            handle: appState.handle,
            width: 300
        )
        .frame(maxWidth: .infinity)
    }

    private var actionsSection: some View {
        HStack(spacing: 12) {
            Button {
                showsPayFlow = true
            } label: {
                Label("Invia", systemImage: "arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())

            Button {
                showsRequest = true
            } label: {
                Label("Richiedi", systemImage: "arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }
}
