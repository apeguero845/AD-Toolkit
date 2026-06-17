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

    // MARK: - AD Config (Phase 1)

    /// Detect AD configuration from dsconfigad -show.
    /// Returns JSON-encoded ADConfigModel data, or nil + error string.
    func detectADConfig(reply: @escaping (Data?, String?) -> Void)

    /// Load AD configuration from the system Keychain.
    /// Returns JSON-encoded ADConfigModel data, or nil + error string.
    func loadADConfig(reply: @escaping (Data?, String?) -> Void)

    /// Save AD configuration to the system Keychain.
    /// `configData` is JSON-encoded ADConfigModel.
    /// Returns success boolean + optional error string.
    func saveADConfig(_ configData: Data, reply: @escaping (Bool, String?) -> Void)
}
