//
//  PasswordChangeView.swift
//  AD Toolkit
//
//  UI for changing the Active Directory password.
//  Flow: AD (via GSS) → Local account → Keychain
//

import SwiftUI

struct PasswordChangeView: View {
    @StateObject private var viewModel = PasswordChangeViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Cambiar Contraseña de Red")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("El cambio se aplica en AD, cuenta local y llavero.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Form
            Group {
                VStack(alignment: .leading, spacing: 12) {
                    LabeledContent("Usuario") {
                        TextField("ej: jperez", text: $viewModel.username)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 250)
                    }

                    LabeledContent("Dominio") {
                        Text("CESARIGLESIAS.LOCAL")
                            .foregroundColor(.secondary)
                    }

                    SecureField("Contraseña actual", text: $viewModel.oldPassword)
                        .textFieldStyle(.roundedBorder)

                    SecureField("Nueva contraseña", text: $viewModel.newPassword)
                        .textFieldStyle(.roundedBorder)

                    SecureField("Confirmar nueva contraseña", text: $viewModel.confirmPassword)
                        .textFieldStyle(.roundedBorder)
                }
            }

            // Password requirements hint
            if !viewModel.newPassword.isEmpty {
                HStack {
                    Image(systemName: viewModel.passwordsMatch ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(viewModel.passwordsMatch ? .green : .red)
                    Text(viewModel.passwordsMatch
                         ? "Las contraseñas nuevas coinciden"
                         : "Las contraseñas nuevas no coinciden")
                        .font(.caption)
                }
            }

            // Action button
            Button(action: {
                viewModel.changePassword()
            }) {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.8)
                    Text("Cambiando...")
                } else {
                    Text("Cambiar Contraseña")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.formValid || viewModel.isLoading)
            .controlSize(.large)

            // Result message
            if let message = viewModel.resultMessage {
                HStack {
                    Image(systemName: viewModel.isSuccess ? "checkmark.circle" : "exclamationmark.circle")
                        .foregroundColor(viewModel.isSuccess ? .green : .red)
                    Text(message)
                        .font(.callout)
                        .foregroundColor(viewModel.isSuccess ? .primary : .red)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(viewModel.isSuccess
                              ? Color.green.opacity(0.1)
                              : Color.red.opacity(0.1))
                )
            }

            // Session log
            if !viewModel.sessionLog.isEmpty {
                Divider()
                Text("Registro de sesión")
                    .font(.caption)
                    .foregroundColor(.secondary)
                ScrollView {
                    Text(viewModel.sessionLog)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 100)
            }

            Spacer()
        }
        .padding()
    }
}

#Preview {
    PasswordChangeView()
}
