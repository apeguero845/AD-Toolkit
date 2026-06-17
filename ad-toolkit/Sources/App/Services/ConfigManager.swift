//
//  ConfigManager.swift
//  AD Toolkit
//
//  Singleton that manages AD configuration at runtime.
//
//  Loads config from the system Keychain (via XPC), caches it in memory,
//  and provides fallback to ADConfig constants. All ViewModels read from here.
//

import Foundation

/// Manages the runtime AD configuration with in-memory caching and XPC proxying.
///
/// The fallback chain is: Keychain → auto-detect → ADConfig constants → nil.
/// On first access, loadConfig() should be called at app launch to populate
/// the cache from the system Keychain.
///
/// Marked @MainActor because `cachedConfig` is read from SwiftUI views
/// and written from Task contexts — the actor guarantees single-threaded access.
@MainActor
class ConfigManager {

    // MARK: - Singleton

    static let shared = ConfigManager()

    private init() {}

    // MARK: - Private State

    private var cachedConfig: ADConfigModel?
    private let xpcService = XPCService()
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    // MARK: - Public API

    /// The currently cached config, or `nil` if not loaded.
    ///
    /// Consumers should use the fallback pattern:
    /// `ConfigManager.shared.config?.domain ?? ADConfig.domain`
    var config: ADConfigModel? {
        return cachedConfig
    }

    /// Returns `true` when a config has been cached in memory.
    var isConfigured: Bool {
        return cachedConfig != nil
    }

    /// Load the AD configuration from the system Keychain via XPC.
    ///
    /// Decodes the JSON response into an `ADConfigModel` and caches it.
    /// Returns `nil` if no config is stored in the Keychain.
    ///
    /// - Throws: `ConfigError.xpcError` if the XPC call fails,
    ///           or `DecodingError` if JSON parsing fails.
    /// - Returns: The cached `ADConfigModel`, or `nil` if no config exists.
    func loadConfig() async throws -> ADConfigModel? {
        let (data, errorString) = await xpcService.loadADConfig()

        if let errorString = errorString {
            throw ConfigError.xpcError(errorString)
        }

        guard let data = data else {
            cachedConfig = nil
            return nil
        }

        let model = try decoder.decode(ADConfigModel.self, from: data)
        cachedConfig = model
        return model
    }

    /// Detect AD configuration by running `dsconfigad -show` on the Helper Tool.
    ///
    /// Parses the output into an `ADConfigModel`. The result is NOT cached —
    /// call `saveConfig(_:)` to persist it.
    ///
    /// - Throws: `ConfigError.xpcError` if the XPC call fails,
    ///           `ConfigError.detectionFailed` if no data is returned,
    ///           or `DecodingError` if JSON parsing fails.
    /// - Returns: A new `ADConfigModel` with `isAutoDetected = true`.
    func detectConfig() async throws -> ADConfigModel {
        let (data, errorString) = await xpcService.detectADConfig()

        if let errorString = errorString {
            throw ConfigError.xpcError(errorString)
        }

        guard let data = data else {
            throw ConfigError.detectionFailed
        }

        return try decoder.decode(ADConfigModel.self, from: data)
    }

    /// Save an AD configuration to the system Keychain via XPC and cache it.
    ///
    /// Encodes the model to JSON, sends it to the Helper Tool which writes
    /// it to the system Keychain. On success, updates the in-memory cache.
    ///
    /// - Throws: `ConfigError.saveFailed` with the error message from the Helper Tool.
    func saveConfig(_ model: ADConfigModel) async throws {
        let data = try encoder.encode(model)
        let (success, errorString) = await xpcService.saveADConfig(data)

        guard success else {
            throw ConfigError.saveFailed(errorString ?? "Error desconocido al guardar la configuración.")
        }

        cachedConfig = model
    }

    // MARK: - Error Types

    enum ConfigError: LocalizedError {
        case xpcError(String)
        case detectionFailed
        case saveFailed(String)

        var errorDescription: String? {
            switch self {
            case .xpcError(let message):
                return message
            case .detectionFailed:
                return "No se pudo detectar la configuración del dominio."
            case .saveFailed(let message):
                return message
            }
        }
    }
}
