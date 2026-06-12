//
//  DiagnosticsView.swift
//  AD Toolkit
//
//  Standalone diagnostics view for quick troubleshooting.
//  Can run independently without triggering join or password change.
//

import SwiftUI

struct DiagnosticsView: View {
    @StateObject private var viewModel = DomainJoinViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Diagnóstico de Red y Dominio")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Verificá la conectividad con el servidor AD antes de realizar operaciones.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Info card
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    Text("Esta prueba verifica: DNS, sincronización de hora, conectividad LDAP y Kerberos.")
                        .font(.callout)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.1))
                )
            }

            // Run button
            Button(action: {
                viewModel.runDiagnostics()
            }) {
                Image(systemName: "arrow.triangle.2.circlepath")
                Text("Ejecutar Diagnóstico")
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isLoading)
            .controlSize(.large)

            if viewModel.isLoading {
                ProgressView("Ejecutando diagnóstico...")
                    .padding()
            }

            // Results
            if !viewModel.diagnosticsResults.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Resultados")
                        .font(.headline)

                    ForEach(Array(viewModel.diagnosticsResults.keys.sorted()), id: \.self) { key in
                        HStack {
                            Image(systemName: viewModel.diagnosticsResults[key] == "pass"
                                  ? "checkmark.circle.fill"
                                  : viewModel.diagnosticsResults[key] == "bound"
                                  ? "info.circle.fill"
                                  : "xmark.circle.fill")
                                .foregroundColor(viewModel.diagnosticsResults[key] == "pass" || viewModel.diagnosticsResults[key] == "bound"
                                                  ? .green : .red)
                                .font(.title3)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(diagLabel(for: key))
                                    .font(.body)
                                Text(diagHint(for: key, value: viewModel.diagnosticsResults[key] ?? ""))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Text(diagValueLabel(viewModel.diagnosticsResults[key] ?? ""))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.1))
                )
            }

            // Help section
            if viewModel.diagnosticsResults.values.contains("fail") {
                Divider()
                Text("Pasos recomendados")
                    .font(.headline)

                if viewModel.diagnosticsResults["dns"] == "fail" {
                    DiagnosticStep(number: 1,
                                    text: "Configurar DNS en Redes > DNS, agregar la IP del controlador de dominio.")
                }
                if viewModel.diagnosticsResults["time"] == "fail" {
                    DiagnosticStep(number: 2,
                                    text: "Sincronizar hora: `sudo sntp -sS 172.16.7.250`")
                }
                if viewModel.diagnosticsResults["ldap"] == "fail" || viewModel.diagnosticsResults["kdc"] == "fail" {
                    DiagnosticStep(number: 3,
                                    text: "Verificar conectividad VPN/red corporativa.")
                }
            }

            Spacer()
        }
        .padding()
    }

    private func diagLabel(for key: String) -> String {
        switch key {
        case "dns": return "Resolución DNS"
        case "time": return "Sincronización de hora"
        case "ldap": return "Conectividad LDAP"
        case "kdc": return "Conectividad Kerberos (KDC)"
        case "bind": return "Estado del dominio"
        default: return key
        }
    }

    private func diagHint(for key: String, value: String) -> String {
        if value == "pass" || value == "bound" { return "" }
        switch key {
        case "dns": return "No se resuelve cesariglesias.local"
        case "time": return "Diferencia horaria mayor a 5 minutos"
        case "ldap": return "No se puede contactar el puerto LDAP"
        case "kdc": return "No se puede contactar el KDC (puerto 464)"
        default: return ""
        }
    }

    private func diagValueLabel(_ value: String) -> String {
        switch value {
        case "pass": return "✅ OK"
        case "fail": return "❌ Error"
        case "bound": return "🔗 Unido"
        case "not_bound": return "⬜ No unido"
        default: return value
        }
    }
}

struct DiagnosticStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number).")
                .font(.callout)
                .foregroundColor(.secondary)
            Text(text)
                .font(.callout)
        }
        .padding(.leading, 4)
    }
}

#Preview {
    DiagnosticsView()
}
