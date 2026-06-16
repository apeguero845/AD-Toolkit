//
//  gss_bridge.h
//  AD Toolkit
//
//  C wrapper around GSS.framework for Kerberos password change.
//  Uses gss_aapl_change_password() — Apple's public API for
//  changing Kerberos passwords in Active Directory.
//
//  References:
//    - <GSS/gssapi_apple.h> — Apple extensions to GSS-API
//    - xcreds (Twocanoes): KerbUtil.m implementation
//

#ifndef gss_bridge_h
#define gss_bridge_h

#import <Foundation/Foundation.h>

/// Result of a GSS password change operation.
///
/// - Note: `error_message` is always dynamically allocated with strdup() when
///   non-NULL. The caller MUST call free() on it after use to avoid leaks.
typedef struct {
    bool success;
    int kerberos_error_code;
    const char *error_message;
} gss_password_change_result_t;

/// Change a Kerberos password using GSS.framework.
///
/// Uses `gss_aapl_change_password()` which communicates directly
/// with the KDC via the Kerberos protocol (port 464/tcp).
///
/// - Parameters:
///   - userPrincipal: Full user principal (e.g., "user@COMPANY.LOCAL")
///   - oldPassword: Current password
///   - newPassword: New password (must meet AD GPO complexity requirements)
/// - Returns: A `gss_password_change_result_t` struct.
///   The caller MUST call free() on `error_message` if it is non-NULL.
gss_password_change_result_t gss_change_password(
    const char *userPrincipal,
    const char *oldPassword,
    const char *newPassword
);

/// Get a human-readable description for a Kerberos error code.
const char *gss_error_description(int errorCode);

#endif /* gss_bridge_h */
