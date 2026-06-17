//
//  XPCServer.swift
//  HelperTool
//
//  Implementation of the XPC service that executes privileged operations.
//  All methods run as root via the launch daemon context.
//
//  Security note: Passwords are passed via environment variables, NOT
//  command-line arguments, to avoid leaking credentials via `ps`.
//

import Foundation
import OpenDirectory
import SystemConfiguration

class XPCServer: NSObject, ADToolkitXPCProtocol {

    // MARK: - Configuration Constants

    // MARK: - Diagnostics

    func runDiagnostics(reply: @escaping ([String: String]) -> Void) {
        var results: [String: String] = [:]

        // 1. DNS resolution via SRV record (authoritative for AD)
        let dnsSRV = run("host -t SRV _ldap._tcp.dc._msdcs.\(ADConfig.domain)")
        results["dns"] = dnsSRV == nil ? "fail" : "pass"

        // 2. Time sync check
        let timeResult = run("sntp \(ADConfig.dcIP)")
        results["time"] = (timeResult?.contains("adjust") ?? false ||
                           timeResult?.contains("step") ?? false ||
                           timeResult?.contains("no change") ?? false) ? "pass" : "fail"

        // 3. LDAP reachability
        let ldapResult = run("ldapsearch -H ldap://\(ADConfig.domain) -x -b '' -s base 'objectclass=*' namingContexts 2>/dev/null")
        results["ldap"] = (ldapResult?.contains("namingContexts") ?? false) ? "pass" : "fail"

        // 4. Kerberos KDC port check (tcp/464)
        let kdcResult = run("nc -z -w 3 \(ADConfig.dcIP) 464 2>&1")
        results["kdc"] = (kdcResult?.contains("succeeded") ?? false || kdcResult?.isEmpty ?? false) ? "pass" : "fail"

        // 5. Current bind status
        let bindResult = run("dsconfigad -show 2>&1")
        results["bind"] = (bindResult?.contains("Active Directory Domain") ?? false) ? "bound" : "not_bound"

        reply(results)
    }

    // MARK: - Domain Join

    func joinDomain(computerName: String,
                    ou: String,
                    adminUser: String,
                    adminPass: String,
                    reply: @escaping (Bool, String?) -> Void) {
        let resolvedOU = ou.isEmpty ? ADConfig.defaultOU : ou

        // Pass the admin password via environment variable (not CLI arg)
        let env = ["ADMIN_PASSWORD": adminPass]
        let result = runWithEnv(
            "dsconfigad -add \(ADConfig.domain) "
            + "-computer '\(computerName.escapingSingleQuotes)' "
            + "-username '\(adminUser.escapingSingleQuotes)' "
            + "-ou '\(resolvedOU.escapingSingleQuotes)' "
            + "-passenv ADMIN_PASSWORD "
            + "-force 2>&1",
            environment: env
        )

        guard let output = result else {
            reply(false, "Error al ejecutar dsconfigad. Verificá que el Helper Tool esté instalado correctamente.")
            return
        }

        if output.contains("success") || output.contains("already") {
            reply(true, "✅ Equipo unido al dominio exitosamente.\nDominio: \(ADConfig.domain)\nOU: \(resolvedOU)")
        } else if output.contains("Container does not exist") {
            reply(false, "❌ La OU especificada no existe en AD.\n"
                + "Formato esperado: OU=Computers,DC=company,DC=local\n"
                + "Verificá la ruta con el equipo de infraestructura.")
        } else if output.contains("Invalid credentials") || output.contains("Error 5002") {
            reply(false, "❌ Credenciales inválidas. Verificá el nombre de usuario y contraseña del administrador de dominio.")
        } else if output.contains("Node name wasn't found") || output.contains("Error 2000") {
            reply(false, "❌ No se pudo resolver el nombre del dominio.\n"
                + "Verificá que el DNS esté configurado correctamente (agregar IP del DC en Redes > DNS).")
        } else if output.contains("Authentication server") || output.contains("Error 5200") {
            reply(false, "❌ No se pudo contactar el servidor de autenticación.\n"
                + "Puede ser un problema de sincronización de hora o conectividad de red.")
        } else {
            reply(false, "❌ Error desconocido al unir al dominio.\nDetalles: \(output.prefix(500))")
        }
    }

    // MARK: - Leave Domain

    func leaveDomain(computerName: String,
                     adminUser: String,
                     adminPass: String,
                     reply: @escaping (Bool, String?) -> Void) {
        let env = ["ADMIN_PASSWORD": adminPass]
        let result = runWithEnv(
            "dsconfigad -remove -force "
            + "-computer '\(computerName.escapingSingleQuotes)' "
            + "-username '\(adminUser.escapingSingleQuotes)' "
            + "-passenv ADMIN_PASSWORD 2>&1",
            environment: env
        )

        guard let output = result else {
            reply(false, "Error al ejecutar dsconfigad.")
            return
        }

        if output.contains("success") || output.contains("removed") || output.contains("disconnected") {
            reply(true, "✅ Equipo removido del dominio exitosamente. Se recomienda reiniciar.")
        } else if output.contains("not bound") {
            reply(false, "⚠️ El equipo no está actualmente unido a ningún dominio.")
        } else {
            reply(false, "❌ Error al remover del dominio.\nDetalles: \(output.prefix(300))")
        }
    }

    // MARK: - Local Password Sync

    func syncLocalPassword(username: String,
                           oldPassword: String,
                           newPassword: String,
                           reply: @escaping (Bool, String?) -> Void) {
        do {
            let session = ODSession.default()
            let node = try ODNode(session: session, type: ODNodeType(kODNodeTypeLocalNodes))
            let record = try node.record(withRecordType: kODRecordTypeUsers, name: username, attributes: nil)

            // Use ODRecord.changePassword with the old password to update
            // the local mobile account password. At sync time the local
            // account still has the old password, so this works without
            // needing special root privileges via the auth authority.
            try record.changePassword(oldPassword, toPassword: newPassword)

            reply(true, "Contraseña local sincronizada correctamente.")
        } catch {
            let nsError = error as NSError
            let message: String
            // -14009: kODErrCredentialsRequired, -14165: kODErrPasswordPolicyViolation
            if nsError.code == -14009 || nsError.code == -14165 {
                message = "No se pudo actualizar la cuenta mobile local. "
                    + "El usuario necesitará conectarse a la red corporativa para sincronizar manualmente."
            } else {
                message = "Error al sincronizar contraseña local: \(nsError.localizedDescription)"
            }
            reply(false, message)
        }
    }

    // MARK: - Keychain Sync

    func syncKeychain(username: String,
                      oldPassword: String,
                      newPassword: String,
                      reply: @escaping (Bool, String?) -> Void) {
        // Get the console user's login keychain path (not root's)
        var uid: uid_t = 0
        var gid: gid_t = 0
        let keychainPath: String
        if let userName = SCDynamicStoreCopyConsoleUser(nil, &uid, &gid) as? String {
            let homeDir = NSHomeDirectoryForUser(userName) ?? "/Users/\(userName)"
            keychainPath = "\(homeDir)/Library/Keychains/login.keychain-db"
        } else {
            reply(false, "No se pudo determinar el usuario actual de la consola.")
            return
        }

        // Use Process to call `security set-keychain-password` with direct arguments.
        // SecKeychainChangePassword was removed from Security.framework on macOS 13+,
        // and the security CLI now accepts old/new password as arguments.
        // Process arguments on macOS are only visible to the same UID — we run as root,
        // so regular users cannot see them via `ps`.
        let task = Process()
        let outPipe = Pipe()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        task.arguments = ["set-keychain-password", "-k", keychainPath, oldPassword, newPassword]
        task.standardOutput = outPipe
        task.standardError = outPipe

        do {
            try task.run()
            task.waitUntilExit()

            let data = outPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            if task.terminationStatus == 0 {
                reply(true, "🔑 Keychain actualizado correctamente.")
            } else {
                reply(false, "Error al actualizar el keychain: \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
        } catch {
            reply(false, "Error al ejecutar security CLI: \(error.localizedDescription)")
        }
    }

    // MARK: - AD Config Detection

    func detectADConfig(reply: @escaping (Data?, String?) -> Void) {
        let output = run("dsconfigad -show 2>&1")

        guard let output = output, !output.isEmpty else {
            reply(nil, "No se pudo detectar configuración AD. El equipo no está unido al dominio.")
            return
        }

        guard output.contains("Active Directory Domain") else {
            reply(nil, "No se pudo detectar configuración AD. El equipo no está unido al dominio.")
            return
        }

        var domain: String?
        var forest: String?
        var defaultOU: String?
        var dcHost: String?

        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            let parts = line.components(separatedBy: ": ")
            guard parts.count >= 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts[1...].joined(separator: ": ").trimmingCharacters(in: .whitespaces)

            switch key {
            case "Active Directory Domain":
                domain = value
            case "Active Directory Forest":
                forest = value
            case "Default Computer Container":
                defaultOU = value
            case "Preferred Domain controller":
                dcHost = value
            default:
                break
            }
        }

        guard let resolvedDomain = domain, let resolvedDCHost = dcHost else {
            reply(nil, "No se pudieron leer todos los campos necesarios de dsconfigad.")
            return
        }

        let model = ADConfigModel(
            domain: resolvedDomain,
            dcHost: resolvedDCHost,
            defaultOU: defaultOU ?? "",
            forest: forest,
            isAutoDetected: true
        )

        do {
            let data = try JSONEncoder().encode(model)
            reply(data, nil)
        } catch {
            reply(nil, "Error al codificar la configuración AD: \(error.localizedDescription)")
        }
    }

    // MARK: - AD Config Keychain

    func loadADConfig(reply: @escaping (Data?, String?) -> Void) {
        do {
            let config = try KeychainStore.shared.load()
            let data = try JSONEncoder().encode(config)
            reply(data, nil)
        } catch let error as KeychainError {
            if case .loadFailed(let status) = error, status == errSecItemNotFound {
                reply(nil, nil) // No config stored yet — not an error
            } else {
                reply(nil, error.localizedDescription)
            }
        } catch {
            reply(nil, "Error al cargar configuración AD: \(error.localizedDescription)")
        }
    }

    func saveADConfig(_ configData: Data, reply: @escaping (Bool, String?) -> Void) {
        do {
            let config = try JSONDecoder().decode(ADConfigModel.self, from: configData)
            try KeychainStore.shared.save(config)
            reply(true, nil)
        } catch let error as KeychainError {
            reply(false, error.localizedDescription)
        } catch {
            reply(false, "Error al guardar configuración AD: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Helpers

    /// Run a shell command with no custom environment.
    private func run(_ command: String) -> String? {
        return runWithEnv(command, environment: [:])
    }

    /// Run a shell command with a custom environment dictionary.
    /// Passwords should be passed via `environment`, not inline in `command`.
    ///
    /// - Parameters:
    ///   - command: Shell command to execute
    ///   - environment: Additional environment variables to set
    /// - Returns: Combined stdout+stderr output, or nil on failure
    private func runWithEnv(_ command: String, environment: [String: String]) -> String? {
        let task = Process()
        let pipe = Pipe()

        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-c", command]
        task.standardOutput = pipe
        task.standardError = pipe

        // Merge current environment with additional vars
        var env = ProcessInfo.processInfo.environment
        for (key, value) in environment {
            env[key] = value
        }
        task.environment = env

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return output
        } catch {
            return nil
        }
    }
}

// MARK: - String Extensions

private extension String {
    /// Escape single quotes for safe inclusion in shell command strings.
    /// Replaces `'` with `'\\''` (end quote, escaped quote, start quote).
    var escapingSingleQuotes: String {
        replacingOccurrences(of: "'", with: "'\\''")
    }
}
