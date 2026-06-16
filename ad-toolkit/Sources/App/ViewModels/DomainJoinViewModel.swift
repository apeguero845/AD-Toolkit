//
//  DomainJoinViewModel.swift
//  AD Toolkit
//
//  ViewModel for domain join/leave operations and diagnostics.
//

import Foundation
import Combine

class DomainJoinViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var computerName: String = currentHostName()
    @Published var ouPath: String = ADConfig.defaultOU
    @Published var adminUser: String = ""
    @Published var adminPass: String = ""

    @Published var isLoading = false
    @Published var resultMessage: String? = nil
    @Published var isSuccess = false
    @Published var diagnosticsResults: [String: String] = [:]

    let domain = ADConfig.domain

    // MARK: - Computed Properties

    var formValid: Bool {
        !computerName.isEmpty && !adminUser.isEmpty && !adminPass.isEmpty
    }

    /// Returns true only if diagnostics have been run AND all checks passed.
    /// Resets to false when diagnostics haven't been run yet or any check fails.
    var diagnosticsPassed: Bool {
        guard !diagnosticsResults.isEmpty else { return false }
        return diagnosticsResults.allSatisfy { key, value in
            value == "pass" || value == "bound"
        }
    }

    // MARK: - Actions

    func runDiagnostics() {
        isLoading = true
        diagnosticsResults = [:]

        let xpc = XPCService()
        xpc.runDiagnostics { results in
            DispatchQueue.main.async {
                self.diagnosticsResults = results
                self.isLoading = false
            }
        }
    }

    func joinDomain() {
        guard formValid else { return }
        isLoading = true
        resultMessage = nil

        let xpc = XPCService()
        xpc.joinDomain(computerName: computerName,
                       ou: ouPath,
                       adminUser: adminUser,
                       adminPass: adminPass) { success, message in
            DispatchQueue.main.async {
                self.isSuccess = success
                self.resultMessage = message
                self.adminPass = ""
                self.adminUser = ""
                self.isLoading = false
            }
        }
    }

    func leaveDomain() {
        guard formValid else { return }
        isLoading = true
        resultMessage = nil

        let xpc = XPCService()
        xpc.leaveDomain(computerName: computerName,
                        adminUser: adminUser,
                        adminPass: adminPass) { success, message in
            DispatchQueue.main.async {
                self.isSuccess = success
                self.resultMessage = message
                self.adminPass = ""
                self.adminUser = ""
                self.isLoading = false
            }
        }
    }

    // MARK: - Private

    private static func currentHostName() -> String {
        // Default to current hostname, extracted by helper tool
        return Host.current().localizedName ?? ""
    }
}
