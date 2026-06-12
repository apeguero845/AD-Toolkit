import Foundation

@objc protocol ADToolkitXPCProtocol {
    // Domain join
    func joinDomain(computerName: String,
                    ou: String,
                    adminUser: String,
                    adminPass: String,
                    reply: @escaping (Bool, String?) -> Void)

    // Remove from domain
    func leaveDomain(computerName: String,
                     adminUser: String,
                     adminPass: String,
                     reply: @escaping (Bool, String?) -> Void)

    // Local mobile account password sync
    func syncLocalPassword(username: String,
                           oldPassword: String,
                           newPassword: String,
                           reply: @escaping (Bool, String?) -> Void)

    // Login keychain sync
    func syncKeychain(username: String,
                      oldPassword: String,
                      newPassword: String,
                      reply: @escaping (Bool, String?) -> Void)

    // Run pre-flight diagnostics
    func runDiagnostics(reply: @escaping ([String: String]) -> Void)
}
