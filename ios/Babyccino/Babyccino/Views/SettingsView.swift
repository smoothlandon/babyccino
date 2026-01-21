//
//  SettingsView.swift
//  Babyccino
//
//  Server configuration settings
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var serverClient: ServerClient
    @StateObject private var modelManager = ModelManager.shared
    @Environment(\.dismiss) var dismiss

    @State private var isTesting = false
    @State private var testResult: String?

    var body: some View {
        NavigationView {
            Form {
                // On-Device Model Section
                Section {
                    ForEach(ModelInfo.availableModels) { model in
                        ModelRow(model: model, modelManager: modelManager)
                    }
                } header: {
                    Text("On-Device Model")
                } footer: {
                    Text("Models run locally on your device for private conversations. Select one to download and use.")
                        .font(.caption)
                }

                // Server Configuration Section
                Section {
                    TextField("Server URL", text: $serverClient.serverURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()

                    Text("Example: http://192.168.1.100:8000")
                        .font(.caption)
                        .foregroundColor(.gray)
                } header: {
                    Text("Server Configuration")
                }

                Section {
                    Button(action: testConnection) {
                        HStack {
                            Text("Test Connection")
                            Spacer()
                            if isTesting {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isTesting)

                    if let result = testResult {
                        Text(result)
                            .font(.caption)
                            .foregroundColor(serverClient.isConnected ? .green : .red)
                    }

                    if let health = serverClient.serverHealth {
                        VStack(alignment: .leading, spacing: 8) {
                            InfoRow(label: "Status", value: health.status)
                            InfoRow(label: "Version", value: health.version)
                            InfoRow(label: "Model", value: health.model)
                            InfoRow(label: "Provider", value: health.llmProvider)
                            InfoRow(
                                label: "Model Available",
                                value: health.modelAvailable ? "Yes" : "No"
                            )
                        }
                    }
                } header: {
                    Text("Connection Status")
                }

                Section {
                    Text("Babyccino v0.1.0")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Text("A conversational development tool for generating Python functions with tests and complexity analysis.")
                        .font(.caption)
                        .foregroundColor(.gray)
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func testConnection() {
        isTesting = true
        testResult = nil

        Task {
            do {
                _ = try await serverClient.checkHealth()
                testResult = "✓ Connected successfully"
            } catch {
                testResult = "✗ \(error.localizedDescription)"
            }
            isTesting = false
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.caption)
    }
}

struct ModelRow: View {
    let model: ModelInfo
    @ObservedObject var modelManager: ModelManager

    var downloadState: ModelDownloadState {
        modelManager.downloadStates[model.id] ?? .notDownloaded
    }

    var isSelected: Bool {
        modelManager.selectedModelId == model.id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.displayName)
                        .font(.headline)

                    HStack(spacing: 12) {
                        // Quality stars
                        HStack(spacing: 2) {
                            ForEach(0..<5) { i in
                                Image(systemName: i < model.quality ? "star.fill" : "star")
                                    .font(.caption2)
                                    .foregroundColor(i < model.quality ? .yellow : .gray)
                            }
                        }

                        // Speed badge
                        Text(model.speed.rawValue)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(speedColor.opacity(0.2))
                            .foregroundColor(speedColor)
                            .cornerRadius(4)

                        // Size
                        Text("\(model.sizeInMB) MB")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                Spacer()

                // Selected checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }

            Text(model.description)
                .font(.caption)
                .foregroundColor(.gray)
                .fixedSize(horizontal: false, vertical: true)

            // Download/Action buttons
            HStack(spacing: 8) {
                switch downloadState {
                case .notDownloaded:
                    Button(action: { downloadModel() }) {
                        Label("Download", systemImage: "arrow.down.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)

                case .downloading(let progress):
                    VStack(spacing: 4) {
                        ProgressView(value: progress)
                        Text("\(Int(progress * 100))%")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    Button(action: { modelManager.cancelDownload(model.id) }) {
                        Text("Cancel")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)

                case .downloaded:
                    if !isSelected {
                        Button(action: { modelManager.selectModel(model.id) }) {
                            Label("Use This Model", systemImage: "checkmark.circle")
                                .font(.caption)
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Text("Currently Active")
                            .font(.caption)
                            .foregroundColor(.green)
                            .fontWeight(.medium)
                    }

                    // Show model size
                    if let size = modelManager.modelSize(for: model.id) {
                        Text(modelManager.formatBytes(size))
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }

                    Button(action: { deleteModel() }) {
                        Label("Delete", systemImage: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .disabled(isSelected)

                case .failed(let error):
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Download failed")
                            .font(.caption)
                            .foregroundColor(.red)
                        Text(error)
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Button(action: { downloadModel() }) {
                            Text("Retry")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var speedColor: Color {
        switch model.speed {
        case .fast: return .green
        case .medium: return .orange
        case .slow: return .red
        }
    }

    private func downloadModel() {
        Task {
            do {
                try await modelManager.downloadModel(model)
            } catch {
                print("❌ Download failed: \(error)")
            }
        }
    }

    private func deleteModel() {
        Task {
            do {
                try modelManager.deleteModel(model.id)
            } catch {
                print("❌ Delete failed: \(error)")
            }
        }
    }
}
