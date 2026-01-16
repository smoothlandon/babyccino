//
//  SettingsView.swift
//  Babyccino
//
//  Server configuration settings
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var serverClient: ServerClient
    @Environment(\.dismiss) var dismiss

    @State private var isTesting = false
    @State private var testResult: String?

    var body: some View {
        NavigationView {
            Form {
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
