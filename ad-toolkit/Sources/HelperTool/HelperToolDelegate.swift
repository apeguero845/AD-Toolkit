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

    /// Expected bundle ID for the calling app
    private let expectedAppBundleID = "com.cisa.ad-toolkit"

    /// Minimum app version allowed to connect
    private let minimumAppVersion = "1.0.0"

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
    /// (bundle ID + Developer ID certificate) from SMAuthorizedClients.
    ///
    /// - Parameter connection: The incoming XPC connection
    /// - Returns: true if the connection is from a trusted app
    private func validateConnection(_ connection: NSXPCConnection) -> Bool {
        let pid = connection.processIdentifier
        guard pid > 0 else { return false }

        // Create a SecCode from the process PID
        let pidAttribute = [kSecGuestAttributePid: pid] as CFDictionary
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
