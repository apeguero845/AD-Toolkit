//
//  PasswordChangeViewModel.swift
//  AD Toolkit
//
//  ViewModel for the password change flow.
//  Orchestrates: GSS Kerberos change → Local sync → Keychain sync
//

import Foundation
import Combine
import OSLog

class PasswordChangeViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var username: String = ""
    @Published var oldPassword: String = ""
    @Published var newPassword: String = ""
    @Published var confirmPassword: String = ""

    @Published var isLoading = false
    @Published var resultMessage: String? = nil
    @Published var isSuccess = false
    @Published var sessionLog: String = ""

    // MARK: - Computed Properties

    var passwordsMatch: Bool {
        !newPassword.isEmpty && newPassword == confirmPassword
    }

    var formValid: Bool {
        !username.isEmpty &&
        !oldPassword.isEmpty &&
        !newPassword.isEmpty &&
        !confirmPassword.isEmpty &&
        passwordsMatch
    }

    private let domain = "CESARIGLESIAS.LOCAL"

    // MARK: - Actions

    func changePassword() {
        defer { clearPasswords() }

        guard formValid else { return }

        // Validate password complexity before sending to KDC
        if let validationError = validatePasswordComplexity(newPassword) {
            resultMessage = validationError
            isSuccess = false
            return
        }

        // Capture values before async dispatch
        let capturedUsername = username
        let capturedOldPassword = oldPassword
        let capturedNewPassword = newPassword
        let capturedDomain = domain

        isLoading = true
        resultMessage = nil
        isSuccess = false
        appendLog("Iniciando cambio de contraseña para \(capturedUsername)...")

        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }

            // Step 1: Change password in AD via KerberosService
            DispatchQueue.main.async {
                self.appendLog("Paso 1/3: Cambiando contraseña en AD via Kerberos...")
            }

            let kerberosService = KerberosService()
            let kerberosResult = kerberosService.changePassword(
                username: capturedUsername,
                domain: capturedDomain,
                oldPassword: capturedOldPassword,
                newPassword: capturedNewPassword
            )

            guard kerberosResult.success else {
                let errorMsg = kerberosResult.errorMessage ?? "Error desconocido"
                DispatchQueue.main.async {
                    self.appendLog("✗ Error Kerberos: \(errorMsg)")
                    self.resultMessage = errorMsg
                    self.isSuccess = false
                    self.isLoading = false
                }
                return
            }

            DispatchQueue.main.async {
                self.appendLog("✓ Contraseña cambiada en AD exitosamente.")
            }

            // Step 2: Sync local mobile account
            DispatchQueue.main.async {
                self.appendLog("Paso 2/3: Sincronizando cuenta local...")
            }

            let xpc = XPCService()
            var localSyncSuccess = false
            var localSyncMessage = ""

            let localGroup = DispatchGroup()
            localGroup.enter()
            xpc.syncLocalPassword(username: capturedUsername, oldPassword: capturedOldPassword, newPassword: capturedNewPassword) { ok, msg in
                localSyncSuccess = ok
                localSyncMessage = msg ?? ""
                localGroup.leave()
            }
            if localGroup.wait(timeout: .now() + 30) == .timedOut {
                localSyncMessage = "La operación XPC tardó demasiado. Verificá que el Helper Tool esté instalado."
                os_log(.error, "XPC syncLocalPassword timed out for user %{public}@", capturedUsername)
            }

            DispatchQueue.main.async {
                if localSyncSuccess {
                    self.appendLog("✓ Cuenta local sincronizada.")
                } else {
                    self.appendLog("⚠︎ Sync local: \(localSyncMessage)")
                }
            }

            // Step 3: Sync keychain
            DispatchQueue.main.async {
                self.appendLog("Paso 3/3: Actualizando llavero (keychain)...")
            }

            var keychainSuccess = false
            var keychainMessage = ""

            let keychainGroup = DispatchGroup()
            keychainGroup.enter()
            xpc.syncKeychain(username: capturedUsername, oldPassword: capturedOldPassword, newPassword: capturedNewPassword) { ok, msg in
                keychainSuccess = ok
                keychainMessage = msg ?? ""
                keychainGroup.leave()
            }
            if keychainGroup.wait(timeout: .now() + 30) == .timedOut {
                keychainMessage = "La operación XPC de keychain tardó demasiado. Verificá que el Helper Tool esté instalado."
                os_log(.error, "XPC syncKeychain timed out for user %{public}@", capturedUsername)
            }

            // Final result on main thread
            DispatchQueue.main.async {
                if keychainSuccess {
                    self.appendLog("✓ Keychain actualizado.")
                } else {
                    self.appendLog("⚠︎ Keychain: \(keychainMessage)")
                }

                self.isSuccess = true
                self.resultMessage = "Contraseña cambiada correctamente.\n"
                    + "✓ AD actualizado\n"
                    + (localSyncSuccess ? "✓ Cuenta local sincronizada\n" : "⚠︎ Sync local pendiente\n")
                    + (keychainSuccess ? "✓ Llavero actualizado" : "⚠︎ Llavero: \(keychainMessage)")

                if !keychainSuccess {
                    self.resultMessage? += "\n\nPodés actualizar el llavero manualmente desde Keychain Access."
                }

                self.appendLog("✓ Proceso completado.")
                self.isLoading = false

                // Clear sensitive data
                self.oldPassword = ""
                self.newPassword = ""
                self.confirmPassword = ""
            }
        }
    }

    // MARK: - Private

    /// Validate password meets basic AD complexity requirements (GPO-like).
    /// Returns an error message string if validation fails, nil if OK.
    private func validatePasswordComplexity(_ password: String) -> String? {
        if password.count < 8 {
            return "La contraseña debe tener al menos 8 caracteres."
        }
        let hasUppercase = password.rangeOfCharacter(from: .uppercaseLetters) != nil
        let hasLowercase = password.rangeOfCharacter(from: .lowercaseLetters) != nil
        let hasDigit = password.rangeOfCharacter(from: .decimalDigits) != nil
        let hasSpecial = password.rangeOfCharacter(
            from: CharacterSet(charactersIn: "!@#$%^&*()_+-=[]{}|;:',.<>?/~`\"")
        ) != nil

        if !hasUppercase {
            return "La contraseña debe contener al menos una letra mayúscula."
        }
        if !hasLowercase {
            return "La contraseña debe contener al menos una letra minúscula."
        }
        if !hasDigit {
            return "La contraseña debe contener al menos un número."
        }
        if !hasSpecial {
            return "La contraseña debe contener al menos un carácter especial (!@#$%^&* etc.)."
        }
        return nil
    }

    private func clearPasswords() {
        oldPassword = ""
        newPassword = ""
        confirmPassword = ""
    }

    private func appendLog(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        sessionLog += "[\(timestamp)] \(message)\n"
    }
}
