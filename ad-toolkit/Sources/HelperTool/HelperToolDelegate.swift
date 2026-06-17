//
//  HelperToolDelegate.swift
//  HelperTool
//
//  Handles XPC listener events and validates incoming connections
//  using code signing requirements.
//
//  Reference:
//    - EvenBetterAuthorizationSample (Apple — archived)
//    - CSAuthSample (github.com/CharlesJS/CSAuthSample)
//    - SecCodeCopyGuestWithAttributes: Validate calling app identity
//

import Foundation

class HelperToolDelegate: NSObject, NSXPCListenerDelegate {

    func listener(_ listener: NSXPCListener,
                  shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        // In debug builds, accept all connections for development convenience
        #if DEBUG
        let exportedObject = XPCServer()
        newConnection.exportedInterface = NSXPCInterface(with: ADToolkitXPCProtocol.self)
        newConnection.exportedObject = exportedObject
        newConnection.resume()
        return true
        #else
        // In release builds, validate the calling app's identity
        guard validateConnection(newConnection) else {
            NSLog("ADToolkit Helper: Rejected connection from untrusted process (PID: %d)",
                  newConnection.processIdentifier)
            return false
        }

        let exportedObject = XPCServer()
        newConnection.exportedInterface = NSXPCInterface(with: ADToolkitXPCProtocol.self)
        newConnection.exportedObject = exportedObject
        newConnection.resume()
        return true
        #endif
    }

    /// Validate that the calling app is properly signed by our team.
    ///
    /// Uses `SecCodeCopyGuestWithAttributes` with the process PID to obtain
    /// a `SecCodeRef`, then validates it against our exact signing requirement
    /// (Developer ID certificate + bundle ID) from SMAuthorizedClients.
    ///
    /// Note: PID-based guest attribute has a theoretical TOCTOU race (PID could
    /// be reused). The impact is minimal because validation happens immediately
    /// as the connection is established. An audit-token-based approach would be
    /// preferred on SDK versions that expose it.
    ///
    /// - Parameter connection: The incoming XPC connection
    /// - Returns: true if the connection is from a trusted app
    private func validateConnection(_ connection: NSXPCConnection) -> Bool {
        // Note: auditToken is not available in all SDK versions.
        // Using PID-based approach which has a theoretical TOCTOU race
        // (PID reused by a different process before validation completes).
        // In practice this is safe because the connection is validated
        // immediately as it's established.
        var pid = connection.processIdentifier
        let pidData = Data(bytes: &pid, count: MemoryLayout<pid_t>.size)
        let pidAttribute = [kSecGuestAttributePid: pidData] as CFDictionary
        var staticCode: SecCode?
        let status = SecCodeCopyGuestWithAttributes(nil, pidAttribute, [], &staticCode)

        guard status == errSecSuccess, let code = staticCode else {
            return false
        }

        // Build signing requirement matching SMAuthorizedClients in HelperTool-Info.plist
        let requirementString = "identifier \"com.cisa.ad-toolkit\" and anchor apple generic and certificate leaf[subject.CN] = \"Developer ID Application: César Iglesias S.A.\""
        var requirement: SecRequirement?
        let reqStatus = SecRequirementCreateWithString(requirementString as CFString, [], &requirement)

        guard reqStatus == errSecSuccess, let req = requirement else {
            return false
        }

        // Validate the code against our exact signing requirement
        // (checks bundle identifier AND developer certificate)
        let checkValidityStatus = SecCodeCheckValidityWithErrors(code, [], req, nil)
        guard checkValidityStatus == errSecSuccess else {
            return false
        }

        return true
    }

}
