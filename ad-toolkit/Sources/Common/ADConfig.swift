//
//  ADConfig.swift
//  AD Toolkit
//
//  Centralized configuration for Active Directory integration.
//  Set these values to match your AD infrastructure before deploying.
//
//  Security: Do NOT commit real credentials or internal server names.
//  These values are placeholders — replace them in your local build.
//

import Foundation

/// Active Directory configuration constants.
///
/// All values are intentionally left as placeholders.
/// Configure them for your environment before building.
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
