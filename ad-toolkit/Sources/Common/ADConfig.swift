//
//  ADConfig.swift
//  AD Toolkit
//
//  DEPRECATED: Use ConfigManager.shared.config instead.
//  Will be removed in a future version.
//
//  Previously: Centralized configuration for Active Directory integration.
//  Now acts as fallback constants when no runtime config is stored.
//

import Foundation

/// Active Directory configuration constants.
///
/// DEPRECATED: Use `ConfigManager.shared.config` with fallback:
/// `ConfigManager.shared.config?.domain ?? ADConfig.domain`
///
/// These constants remain as fallback during the transition period.
/// They will be removed once all users have migrated to Keychain-stored config.
@available(*, deprecated, message: "Use ConfigManager.shared.config instead")
enum ADConfig {
    /// AD domain in lowercase (e.g., "company.local")
    static let domain = "company.local"

    /// AD domain in uppercase
    static let domainUpper = "COMPANY.LOCAL"

    /// IP address of a domain controller
    static let dcIP = "10.0.0.1"

    /// Default OU path for new computer accounts
    static let defaultOU = "OU=Computers,DC=company,DC=local"
}
