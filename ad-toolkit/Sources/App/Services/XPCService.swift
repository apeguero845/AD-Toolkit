//
//  XPCService.swift
//  AD Toolkit
//
//  Proxy to the privileged helper tool via XPC.
//  All privileged operations (dsconfigad, sysadminctl, keychain)
//  are executed by the helper tool running as root.
//

import Foundation

/// Service that communicates with the privileged helper tool via XPC.
///
/// The helper tool is installed and managed via SMAppService.
/// It runs as root and executes commands that require elevated privileges.
class XPCService {

    private var connection: NSXPCConnection?

    private func connect() -> ADToolkitXPCProtocol? {
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

        return connection?.remoteObjectProxy as? ADToolkitXPCProtocol
    }

    // MARK: - Diagnostics

    func runDiagnostics(reply: @escaping ([String: String]) -> Void) {
        guard let proxy = connect() else {
            reply(["error": "No se pudo conectar con el helper tool. Verificá que esté instalado en Settings > Login Items."])
            return
        }
        proxy.runDiagnostics(reply: reply)
    }

    // MARK: - Domain Join

    func joinDomain(computerName: String,
                    ou: String,
                    adminUser: String,
                    adminPass: String,
                    reply: @escaping (Bool, String?) -> Void) {
        guard let proxy = connect() else {
            reply(false, "No se pudo conectar con el helper tool.")
            return
        }
        proxy.joinDomain(computerName: computerName,
                          ou: ou,
                          adminUser: adminUser,
                          adminPass: adminPass,
                          reply: reply)
    }

    func leaveDomain(computerName: String,
                     adminUser: String,
                     adminPass: String,
                     reply: @escaping (Bool, String?) -> Void) {
        guard let proxy = connect() else {
            reply(false, "No se pudo conectar con el helper tool.")
            return
        }
        proxy.leaveDomain(computerName: computerName,
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
}
