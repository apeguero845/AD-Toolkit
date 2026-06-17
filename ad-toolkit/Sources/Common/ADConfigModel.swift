//
//  ADConfigModel.swift
//  AD Toolkit
//
//  Runtime AD configuration model stored in the system Keychain.
//  Replaces compile-time ADConfig constants at runtime.
//

import Foundation

/// Runtime AD configuration with derived fields.
///
/// All domain-sensitive fields are computed on save by `init`
/// to guarantee consistency — consumers treat this as source of truth.
struct ADConfigModel: Codable {
    /// AD domain in lowercase (e.g., "company.local")
    let domain: String

    /// AD domain in uppercase (e.g., "COMPANY.LOCAL")
    let domainUpper: String

    /// Preferred domain controller hostname
    let dcHost: String

    /// Default OU path for new computer accounts
    let defaultOU: String

    /// Active Directory Forest (optional — nil if not reported by dsconfigad)
    let forest: String?

    /// `true` if parsed from `dsconfigad -show`; `false` for manual entry
    let isAutoDetected: Bool

    /// Timestamp of when this config was first detected or saved
    let detectedAt: Date

    /// Create a config model with automatic domain derivation.
    ///
    /// - Parameters:
    ///   - domain: AD domain (will be normalized to lowercase for storage)
    ///   - dcHost: Preferred domain controller
    ///   - defaultOU: Default OU path
    ///   - forest: AD forest name (optional)
    ///   - isAutoDetected: Whether this came from dsconfigad parsing
    init(domain: String, dcHost: String, defaultOU: String, forest: String?, isAutoDetected: Bool) {
        self.domain = domain.lowercased()
        self.domainUpper = domain.uppercased()
        self.dcHost = dcHost
        self.defaultOU = defaultOU
        self.forest = forest
        self.isAutoDetected = isAutoDetected
        self.detectedAt = Date()
    }
}
