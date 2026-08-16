import SwiftUI

/// Il riquadro mostrato quando manca un permesso o non c'è nulla da mostrare.
///
/// Una lista vuota non spiega niente: se l'accesso è stato negato, l'utente
/// deve capirlo e avere la strada per rimediare.
struct PermissionStateView: View {

    let icon: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (@MainActor () -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Theme.secondaryText)
                .accessibilityHidden(true)

            Text(title)
                .font(Theme.headline)
                .foregroundStyle(Theme.primaryText)
                .multilineTextAlignment(.center)

            Text(message)
                .font(Theme.body)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle).frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 6)
            }
        }
        .padding(28)
        .frame(maxWidth: 380)
        .padding(.horizontal, Theme.screenPadding)
    }
}

/// Un campo di testo incorniciato, in tinta con il resto dell'app.
struct FieldBox<Content: View>: View {

    let title: String
    var error: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(Theme.label)
                .tracking(0.8)
                .foregroundStyle(Theme.tertiaryText)

            content
                .font(Theme.body)
                .foregroundStyle(Theme.primaryText)
                .padding(.horizontal, 16)
                .padding(.vertical, 15)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            error == nil ? Theme.hairline : Theme.destructive.opacity(0.65),
                            lineWidth: 1
                        )
                )

            if let error {
                Text(error)
                    .font(Theme.caption)
                    .foregroundStyle(Theme.destructive)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.riseUp)
            }
        }
    }
}
