//
//  KerberosService.swift
//  AD Toolkit
//
//  Swift wrapper around the C GSS bridge.
//  Provides a Swift-friendly interface for Kerberos password changes.
//

import Foundation

/// Result of a Kerberos password change operation.
struct KerberosPasswordChangeResult {
    let success: Bool
    let errorCode: Int
    let errorMessage: String?
}

/// Service for changing Active Directory passwords via Kerberos.
///
/// Uses GSS.framework internally via the C bridge (gss_bridge.c).
/// This is the recommended approach over kpasswd CLI or dscl/sysadminctl.
///
/// Reference:
///   - gss_aapl_change_password() from <GSS/gssapi_apple.h>
///   - xcreds (Twocanoes) KerbUtil.m — reference implementation
class KerberosService {

    /// Change the user's AD password.
    ///
    /// - Parameters:
    ///   - username: The user's SAM account name (without domain)
    ///   - domain: The AD domain in uppercase (e.g., "CESARIGLESIAS.LOCAL")
    ///   - oldPassword: Current password
    ///   - newPassword: New password
    /// - Returns: Result with success status and error details if any
    func changePassword(username: String,
                        domain: String,
                        oldPassword: String,
                        newPassword: String) -> KerberosPasswordChangeResult {
        let principal = "\(username)@\(domain)"

        let cResult = gss_change_password(
            principal,
            oldPassword,
            newPassword
        )

        let errorMsg: String? = {
            guard let ptr = cResult.error_message else { return nil }
            let str = String(cString: ptr)
            free(UnsafeMutableRawPointer(mutating: ptr))
            return str
        }()

        return KerberosPasswordChangeResult(
            success: cResult.success,
            errorCode: Int(cResult.kerberos_error_code),
            errorMessage: errorMsg
        )
    }
}
