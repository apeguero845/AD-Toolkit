//
//  DomainJoinView.swift
//  AD Toolkit
//
//  UI for joining (or removing) a Mac from the Active Directory domain.
//  Includes pre-flight diagnostics and step-by-step feedback.
//

import SwiftUI

struct DomainJoinView: View {
    @StateObject private var viewModel = DomainJoinViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Unir al Dominio")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Une esta Mac a \(viewModel.domain)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Form
            Group {
                VStack(alignment: .leading, spacing: 12) {
                    LabeledContent("Nombre del equipo") {
                        TextField("ej: CILMACSDTI002", text: $viewModel.computerName)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 250)
                    }

                    LabeledContent("Unidad Organizativa (OU)") {
                        TextField("OU=CISA_Laptops,...", text: $viewModel.ouPath)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 350)
                    }
                    .help("Ruta completa de la OU en AD")

                    Divider()

                    LabeledContent("Usuario administrador") {
                        TextField("ej: soportetecnicoti", text: $viewModel.adminUser)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 250)
                    }

                    SecureField("Contraseña del administrador", text: $viewModel.adminPass)
                        .textFieldStyle(.roundedBorder)
                }
            }

            // Action buttons
            HStack(spacing: 12) {
                // Run diagnostics
                Button(action: {
                    viewModel.runDiagnostics()
                }) {
                    Image(systemName: "stethoscope")
                    Text("Diagnosticar")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isLoading)

                // Join domain
                Button(action: {
                    viewModel.joinDomain()
                }) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.8)
                        Text("Uniendo...")
                    } else {
                        Image(systemName: "rectangle.connected.to.line.below.fill")
                        Text("Unir al Dominio")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.formValid || viewModel.isLoading || !viewModel.diagnosticsPassed)

                // Leave domain
                Button(action: {
                    viewModel.leaveDomain()
                }) {
                    Image(systemName: "xmark.rectangle")
                    Text("Remover del Dominio")
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(viewModel.isLoading)
            }
            .controlSize(.large)

            // Diagnostics results
            if !viewModel.diagnosticsResults.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Resultados del diagnóstico")
                        .font(.callout)
                        .fontWeight(.medium)

                    ForEach(Array(viewModel.diagnosticsResults.keys.sorted()), id: \.self) { key in
                        HStack {
                            Image(systemName: viewModel.diagnosticsResults[key] == "pass"
                                  ? "checkmark.circle.fill"
                                  : viewModel.diagnosticsResults[key] == "bound"
                                  ? "info.circle.fill"
                                  : "xmark.circle.fill")
                                .foregroundColor(viewModel.diagnosticsResults[key] == "pass" || viewModel.diagnosticsResults[key] == "bound"
                                                  ? .green : .red)
                            Text(keyLabel(for: key))
                                .font(.caption)
                            Spacer()
                            Text(keyValueLabel(viewModel.diagnosticsResults[key] ?? ""))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.1))
                )
            }

            // Result message
            if let message = viewModel.resultMessage {
                HStack {
                    Image(systemName: viewModel.isSuccess ? "checkmark.circle" : "exclamationmark.circle")
                        .foregroundColor(viewModel.isSuccess ? .green : .red)
                    Text(message)
                        .font(.callout)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(viewModel.isSuccess
                              ? Color.green.opacity(0.1)
                              : Color.red.opacity(0.1))
                )
            }

            Spacer()
        }
        .padding()
    }

    private func keyLabel(for key: String) -> String {
        switch key {
        case "dns": return "DNS"
        case "time": return "Sincronización de hora"
        case "ldap": return "Conectividad LDAP"
        case "kdc": return "Conectividad KDC (Kerberos)"
        case "bind": return "Estado actual del dominio"
        default: return key
        }
    }

    private func keyValueLabel(_ value: String) -> String {
        switch value {
        case "pass": return "✅ Correcto"
        case "fail": return "❌ Error"
        case "bound": return "🔗 Unido actualmente"
        case "not_bound": return "⬜ No unido"
        default: return value
        }
    }
}

#Preview {
    DomainJoinView()
}
