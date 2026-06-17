//
//  XPCService.swift
//  AD Toolkit
//
//  Proxy to the privileged helper tool via XPC.
//  All privileged operations (dsconfigad, sysadminctl, keychain)
//  are executed by the helper tool running as root.
//

import Foundation
import OSLog

/// Service that communicates with the privileged helper tool via XPC.
///
/// The helper tool is installed and managed via SMAppService.
/// It runs as root and executes commands that require elevated privileges.
class XPCService {

    private var connection: NSXPCConnection?

    /// Ensure the XPC connection exists and return it.
    private func ensureConnection() -> NSXPCConnection? {
        if connection == nil {
            let newConnection = NSXPCConnection(machServiceName: "com.cisa.ad-toolkit.helper")
            newConnection.remoteObjectInterface = NSXPCInterface(with: ADToolkitXPCProtocol.self)
            newConnection.interruptionHandler = { [weak self] in
                self?.connection = nil
            }
            newConnection.invalidationHandler = { [weak self] in
                self?.connection = nil
            }
            newConnection.resume()
            connection = newConnection
        }
        return connection
    }

    /// Get proxy for callback-based XPC calls.
    /// Uses `remoteObjectProxyWithErrorHandler` to avoid silently dropping messages.
    private func connect() -> ADToolkitXPCProtocol? {
        guard let connection = ensureConnection() else { return nil }
        return connection.remoteObjectProxyWithErrorHandler { error in
            os_log(.error, "XPC remoteObjectProxy error: %{public}@", error.localizedDescription)
        } as? ADToolkitXPCProtocol
    }

    /// Get proxy for async XPC calls with an error handler that resumes the continuation.
    private func proxyWithErrorHandler(_ onError: @escaping (String) -> Void) -> ADToolkitXPCProtocol? {
        guard let connection = ensureConnection() else { return nil }
        return connection.remoteObjectProxyWithErrorHandler { error in
            onError("XPC connection error: \(error.localizedDescription)")
        } as? ADToolkitXPCProtocol
    }

    // MARK: - Diagnostics

    func runDiagnostics(domain: String,
                        dcHost: String,
                        defaultOU: String,
                        reply: @escaping ([String: String]) -> Void) {
        guard let proxy = connect() else {
            reply(["error": "No se pudo conectar con el helper tool. Verificá que esté instalado en Settings > Login Items."])
            return
        }
        proxy.runDiagnostics(domain: domain, dcHost: dcHost, defaultOU: defaultOU, reply: reply)
    }

    // MARK: - Domain Join

    func joinDomain(computerName: String,
                    domain: String,
                    dcHost: String,
                    ou: String,
                    defaultOU: String,
                    adminUser: String,
                    adminPass: String,
                    reply: @escaping (Bool, String?) -> Void) {
        guard let proxy = connect() else {
            reply(false, "No se pudo conectar con el helper tool.")
            return
        }
        proxy.joinDomain(computerName: computerName,
                          domain: domain,
                          dcHost: dcHost,
                          ou: ou,
                          defaultOU: defaultOU,
                          adminUser: adminUser,
                          adminPass: adminPass,
                          reply: reply)
    }

    func leaveDomain(computerName: String,
                     domain: String,
                     dcHost: String,
                     defaultOU: String,
                     adminUser: String,
                     adminPass: String,
                     reply: @escaping (Bool, String?) -> Void) {
        guard let proxy = connect() else {
            reply(false, "No se pudo conectar con el helper tool.")
            return
        }
        proxy.leaveDomain(computerName: computerName,
                          domain: domain,
                          dcHost: dcHost,
                          defaultOU: defaultOU,
                          adminUser: adminUser,
                          adminPass: adminPass,
                          reply: reply)
    }

    // MARK: - Local Password Sync

    func syncLocalPassword(username: String,
                           oldPassword: String,
                           newPassword: String,
                           reply: @escaping (Bool, String?) -> Void) {
        guard let proxy = connect() else {
            reply(false, "No se pudo conectar con el helper tool.")
            return
        }
        proxy.syncLocalPassword(username: username,
                                 oldPassword: oldPassword,
                                 newPassword: newPassword,
                                 reply: reply)
    }

    // MARK: - Keychain Sync

    func syncKeychain(username: String,
                      oldPassword: String,
                      newPassword: String,
                      reply: @escaping (Bool, String?) -> Void) {
        guard let proxy = connect() else {
            reply(false, "No se pudo conectar con el helper tool.")
            return
        }
        proxy.syncKeychain(username: username,
                            oldPassword: oldPassword,
                            newPassword: newPassword,
                            reply: reply)
    }

    // MARK: - AD Config (Phase 1)

    /// Detect AD configuration via dsconfigad on the Helper Tool.
    /// - Returns: JSON-encoded ADConfigModel data, or nil + error string.
    func detectADConfig() async -> (data: Data?, error: String?) {
        await withCheckedContinuation { continuation in
            var hasResumed = false
            guard let proxy = proxyWithErrorHandler({ error in
                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume(returning: (nil, error))
            }) else {
                continuation.resume(returning: (nil, "No se pudo conectar con el helper tool."))
                return
            }
            proxy.detectADConfig { data, error in
                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume(returning: (data, error))
            }
        }
    }

    /// Load AD configuration from the system Keychain via the Helper Tool.
    /// - Returns: JSON-encoded ADConfigModel data, or nil + error string.
    func loadADConfig() async -> (data: Data?, error: String?) {
        await withCheckedContinuation { continuation in
            var hasResumed = false
            guard let proxy = proxyWithErrorHandler({ error in
                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume(returning: (nil, error))
            }) else {
                continuation.resume(returning: (nil, "No se pudo conectar con el helper tool."))
                return
            }
            proxy.loadADConfig { data, error in
                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume(returning: (data, error))
            }
        }
    }

    /// Save AD configuration to the system Keychain via the Helper Tool.
    /// - Parameter configData: JSON-encoded ADConfigModel data.
    /// - Returns: Success boolean + optional error string.
    func saveADConfig(_ configData: Data) async -> (success: Bool, error: String?) {
        await withCheckedContinuation { continuation in
            var hasResumed = false
            guard let proxy = proxyWithErrorHandler({ error in
                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume(returning: (false, error))
            }) else {
                continuation.resume(returning: (false, "No se pudo conectar con el helper tool."))
                return
            }
            proxy.saveADConfig(configData) { success, error in
                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume(returning: (success, error))
            }
        }
    }
}
