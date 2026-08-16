import SwiftUI

/// Lo storico dei movimenti sotto la home.
struct ActivityListView: View {

    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Attività")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.primaryText)

                Spacer()

                if !appState.transactions.isEmpty {
                    Text("\(appState.transactions.count)")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.tertiaryText)
                }
            }

            if appState.transactions.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(appState.transactions.enumerated()), id: \.element.id) { index, transaction in
                        TransactionRow(transaction: transaction)

                        if index < appState.transactions.count - 1 {
                            Divider()
                                .overlay(Theme.hairline)
                                .padding(.leading, 52)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.035))
                )
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(Theme.tertiaryText)

            Text("Nessun movimento")
                .font(Theme.body)
                .foregroundStyle(Theme.secondaryText)

            Text("I pagamenti che invii compaiono qui.")
                .font(Theme.caption)
                .foregroundStyle(Theme.tertiaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.035))
        )
    }
}

/// Una riga dello storico.
struct TransactionRow: View {

    let transaction: Transaction
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(spacing: 12) {
            InitialsBadge(name: transaction.counterpartName, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.counterpartName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(1)

                Text(transaction.dateText)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.tertiaryText)
            }

            Spacer(minLength: 8)

            Text(transaction.signedAmountText)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(
                    transaction.direction == .received ? Theme.faceID : Theme.primaryText
                )
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .contextMenu {
            Button(role: .destructive) {
                withAnimation(.smooth(duration: 0.3)) {
                    appState.deleteTransaction(transaction)
                }
            } label: {
                Label("Elimina", systemImage: "trash")
            }
        }
    }
}
