//
//  ConfigSetupView.swift
//  AD Toolkit
//
//  First-run configuration sheet shown when no AD config is stored.
//  Offers auto-detection from dsconfigad or manual entry.
//

import SwiftUI

/// Configuration setup sheet displayed on first launch when no Keychain config exists.
struct ConfigSetupView: View {
    @Binding var isPresented: Bool

    @State private var mode: Mode = .menu
    @State private var isSaving = false
    @State private var errorMessage: String?

    // Manual entry fields
    @State private var manualDomain = ""
    @State private var manualDcHost = ""
    @State private var manualDefaultOU = ""

    // Auto-detect state
    @State private var detectedModel: ADConfigModel?
    @State private var isDetecting = false
    @State private var detectionError: String?

    enum Mode: String, Identifiable {
        case menu
        case autoDetect
        case manual
        case review

        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 20) {
            switch mode {
            case .menu:
                menuContent
            case .autoDetect:
                autoDetectContent
            case .manual:
                manualContent
            case .review:
                reviewContent
            }
        }
        .padding()
        .frame(width: 480)
    }

    // MARK: - Menu

    private var menuContent: some View {
        VStack(spacing: 24) {
            Image(systemName: "gearshape.2.fill")
                .font(.system(size: 40))
                .foregroundColor(.accentColor)

            Text("Configuración de Active Directory")
                .font(.title2)
                .fontWeight(.semibold)

            Text("No se encontró una configuración guardada. Elegí cómo querés configurar la conexión al dominio.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundColor(.red)
            }

            VStack(spacing: 12) {
                Button(action: { startAutoDetect() }) {
                    Label("Auto-detectar desde el dominio", systemImage: "antenna.radiowaves.left.and.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(action: {
                    mode = .manual
                }) {
                    Label("Ingresar manualmente", systemImage: "pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            Button("Cancelar") {
                isPresented = false
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
        }
    }

    // MARK: - Auto-Detect

    private var autoDetectContent: some View {
        VStack(spacing: 20) {
            if isDetecting {
                ProgressView("Detectando configuración del dominio...")
                    .padding(.vertical, 40)
            } else if let error = detectionError {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.orange)

                Text("No se pudo detectar la configuración")
                    .font(.headline)

                Text(error)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 12) {
                    Button("Intentar de nuevo") {
                        startAutoDetect()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Ingresar manualmente") {
                        mode = .manual
                    }
                    .buttonStyle(.bordered)
                }
            } else if let model = detectedModel {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.green)
                        .frame(maxWidth: .infinity)

                    Text("Configuración detectada")
                        .font(.headline)
                        .frame(maxWidth: .infinity)

                    Group {
                        detailRow(label: "Dominio", value: model.domain)
                        detailRow(label: "Domain Controller", value: model.dcHost)
                        detailRow(label: "OU por defecto", value: model.defaultOU)
                        if let forest = model.forest {
                            detailRow(label: "Forest", value: forest)
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.1))
                )

                HStack(spacing: 12) {
                    Button("Cancelar") {
                        mode = .menu
                    }
                    .buttonStyle(.bordered)

                    Button("Guardar configuración") {
                        saveConfig(model)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSaving)
                }
            }

            if isSaving {
                ProgressView()
            }
        }
    }

    // MARK: - Manual Entry

    private var manualContent: some View {
        VStack(spacing: 20) {
            Text("Configuración manual")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(spacing: 12) {
                LabeledContent("Dominio") {
                    TextField("ej: empresa.local", text: $manualDomain)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 250)
                }

                LabeledContent("Domain Controller") {
                    TextField("ej: dc01.empresa.local", text: $manualDcHost)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 250)
                }

                LabeledContent("OU por defecto") {
                    TextField("ej: OU=Computers,DC=empresa,DC=local", text: $manualDefaultOU)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 250)
                }
            }

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundColor(.red)
            }

            HStack(spacing: 12) {
                Button("Volver") {
                    mode = .menu
                    errorMessage = nil
                }
                .buttonStyle(.bordered)

                Button("Guardar") {
                    saveManualConfig()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSaving || manualDomain.isEmpty || manualDcHost.isEmpty)
            }

            if isSaving {
                ProgressView()
            }
        }
    }

    // MARK: - Review (saved confirmation)

    private var reviewContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.icloud.fill")
                .font(.system(size: 44))
                .foregroundColor(.green)

            Text("Configuración guardada")
                .font(.title2)
                .fontWeight(.semibold)

            Text("La configuración de Active Directory se guardó en el llavero del sistema.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Comenzar") {
                isPresented = false
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label + ":")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 110, alignment: .trailing)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
            Spacer()
        }
    }

    private func startAutoDetect() {
        isDetecting = true
        detectionError = nil
        errorMessage = nil

        Task {
            do {
                let model = try await ConfigManager.shared.detectConfig()
                await MainActor.run {
                    detectedModel = model
                    isDetecting = false
                    mode = .autoDetect
                }
            } catch {
                await MainActor.run {
                    detectionError = error.localizedDescription
                    isDetecting = false
                    mode = .autoDetect
                }
            }
        }
    }

    private func saveConfig(_ model: ADConfigModel) {
        isSaving = true
        errorMessage = nil

        Task {
            do {
                try await ConfigManager.shared.saveConfig(model)
                await MainActor.run {
                    isSaving = false
                    mode = .review
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSaving = false
                }
            }
        }
    }

    private func saveManualConfig() {
        guard !manualDomain.isEmpty, !manualDcHost.isEmpty else { return }

        let model = ADConfigModel(
            domain: manualDomain,
            dcHost: manualDcHost,
            defaultOU: manualDefaultOU.isEmpty ? "OU=Computers,\(manualDomain.replacingOccurrences(of: ".", with: ",DC="))" : manualDefaultOU,
            forest: nil,
            isAutoDetected: false
        )

        saveConfig(model)
    }
}

#Preview {
    ConfigSetupView(isPresented: .constant(true))
}
