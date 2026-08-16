import SwiftUI

/// Lo storico dei movimenti, come sezione della lista della home.
struct HistoryListSection: View {

    @EnvironmentObject private var appState: AppState

    var body: some View {
        Section {
            if appState.transactions.isEmpty {
                emptyState
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(appState.transactions) { transaction in
                    TransactionRow(transaction: transaction)
                        .listRowBackground(Theme.surface)
                        .listRowSeparatorTint(Theme.hairline)
                        // Scorrimento laterale: il gesto di sistema, non una
                        // sua imitazione.
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                delete(transaction)
                            } label: {
                                Label("Elimina", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                delete(transaction)
                            } label: {
                                Label("Elimina", systemImage: "trash")
                            }
                        }
                }
            }
        } header: {
            HStack {
                Text("Attività")
                    .font(Theme.headline)
                    .foregroundStyle(Theme.primaryText)
                    .textCase(nil)

                Spacer()

                if !appState.transactions.isEmpty {
                    Text("\(appState.transactions.count)")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.tertiaryText)
                }
            }
            .padding(.top, 8)
        }
    }

    private func delete(_ transaction: Transaction) {
        withAnimation(Motion.detail) {
            appState.deleteTransaction(id: transaction.id)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(Theme.tertiaryText)
                .accessibilityHidden(true)

            Text("Nessun movimento")
                .font(Theme.body)
                .foregroundStyle(Theme.secondaryText)

            Text("I pagamenti che invii compaiono qui.")
                .font(Theme.caption)
                .foregroundStyle(Theme.tertiaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
