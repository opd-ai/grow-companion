import SwiftUI

struct BackupPasswordSheet: View {
    let title: String
    let subtitle: String
    let action: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var password = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text(title)
                    .font(Theme.serif(28))
                    .foregroundStyle(Theme.ink)
                Text(subtitle)
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.secondaryInk)
                SecureField("Password (8 characters or more)", text: $password)
                    .textFieldStyle(.plain)
                    .font(Theme.sans(16))
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.surfaceSunken))
                Spacer()
            }
            .padding(20)
            .background(Theme.background)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.foregroundStyle(Theme.primary) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Continue") {
                        action(password)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.primary)
                    .disabled(password.count < 8)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
