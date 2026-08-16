import SwiftUI

/// Una riga dello storico.
struct TransactionRow: View {

    let transaction: Transaction

    var body: some View {
        HStack(spacing: 12) {
            InitialsBadge(name: transaction.counterpartName, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.counterpartName)
                    .font(Theme.bodyEmphasis)
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(1)

                Text(TransactionRow.dateText(for: transaction.date))
                    .font(Theme.caption)
                    .foregroundStyle(Theme.tertiaryText)
            }

            Spacer(minLength: 8)

            Text(transaction.signedAmountText)
                .font(Theme.bodyEmphasis)
                .monospacedDigit()
                .foregroundStyle(
                    transaction.direction == .received ? Theme.positive : Theme.primaryText
                )
                .lineLimit(1)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            transaction.direction == .sent
                ? "Inviati a \(transaction.counterpartName)"
                : "Ricevuti da \(transaction.counterpartName)"
        )
        .accessibilityValue(
            "\(transaction.amount.formattedExact()), \(TransactionRow.dateText(for: transaction.date))"
        )
    }

    /// "Oggi 14:32", "Ieri 09:10", altrimenti la data estesa.
    static func dateText(for date: Date, calendar: Calendar = .current) -> String {
        let time = timeFormatter.string(from: date)
        if calendar.isDateInToday(date) { return "Oggi \(time)" }
        if calendar.isDateInYesterday(date) { return "Ieri \(time)" }
        return dateFormatter.string(from: date)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateFormat = "d MMM, HH:mm"
        return formatter
    }()
}
