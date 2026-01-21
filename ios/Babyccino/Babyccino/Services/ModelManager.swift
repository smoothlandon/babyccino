//
//  ModelManager.swift
//  Babyccino
//
//  Manages model downloads, caching, and selection
//

import Foundation
import Combine

@MainActor
class ModelManager: ObservableObject {
    static let shared = ModelManager()

    @Published var downloadStates: [String: ModelDownloadState] = [:]
    @Published var selectedModelId: String?

    private let fileManager = FileManager.default
    private let userDefaults = UserDefaults.standard
    private let selectedModelKey = "selectedModelId"

    private init() {
        // Load selected model from UserDefaults
        selectedModelId = userDefaults.string(forKey: selectedModelKey)

        // Check which models are already downloaded
        Task {
            await updateDownloadStates()
        }
    }

    /// Get the models directory in the app's cache
    private var modelsDirectory: URL {
        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return cacheDir.appendingPathComponent("models", isDirectory: true)
    }

    /// Get the directory for a specific model
    func modelDirectory(for modelId: String) -> URL {
        return modelsDirectory.appendingPathComponent(modelId, isDirectory: true)
    }

    /// Check if a model is downloaded
    func isModelDownloaded(_ modelId: String) -> Bool {
        let modelDir = modelDirectory(for: modelId)
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: modelDir.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    /// Get the size of a downloaded model in bytes
    func modelSize(for modelId: String) -> Int64? {
        guard isModelDownloaded(modelId) else { return nil }

        let modelDir = modelDirectory(for: modelId)
        var totalSize: Int64 = 0

        if let enumerator = fileManager.enumerator(at: modelDir, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(fileSize)
                }
            }
        }

        return totalSize
    }

    /// Update download states for all models
    func updateDownloadStates() async {
        for model in ModelInfo.availableModels {
            if isModelDownloaded(model.id) {
                downloadStates[model.id] = .downloaded
            } else if downloadStates[model.id] == nil {
                downloadStates[model.id] = .notDownloaded
            }
        }
    }

    /// Download a model from HuggingFace
    func downloadModel(_ modelInfo: ModelInfo) async throws {
        // Create models directory if needed
        try fileManager.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)

        let modelDir = modelDirectory(for: modelInfo.id)

        // Set downloading state
        downloadStates[modelInfo.id] = .downloading(progress: 0.0)

        do {
            // Create model directory
            try fileManager.createDirectory(at: modelDir, withIntermediateDirectories: true)

            // Download required files from HuggingFace
            let filesToDownload = [
                "config.json",
                "tokenizer.json",
                "tokenizer_config.json",
                "model.safetensors"  // Or weights.00.safetensors for split models
            ]

            let baseURL = "https://huggingface.co/\(modelInfo.huggingFaceRepo)/resolve/main"

            for (index, filename) in filesToDownload.enumerated() {
                let fileURL = URL(string: "\(baseURL)/\(filename)")!
                let destinationURL = modelDir.appendingPathComponent(filename)

                print("📥 Downloading \(filename)...")

                // Download file with progress tracking
                try await downloadFile(from: fileURL, to: destinationURL, modelId: modelInfo.id, fileIndex: index, totalFiles: filesToDownload.count)
            }

            // Mark as downloaded
            downloadStates[modelInfo.id] = .downloaded

            print("✅ Model downloaded: \(modelInfo.displayName)")

        } catch {
            // Clean up partial download
            try? fileManager.removeItem(at: modelDir)
            downloadStates[modelInfo.id] = .failed(error: error.localizedDescription)
            throw error
        }
    }

    /// Download a single file with progress tracking
    private func downloadFile(from url: URL, to destination: URL, modelId: String, fileIndex: Int, totalFiles: Int) async throws {
        let (tempURL, response) = try await URLSession.shared.download(from: url)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ModelDownloadError.downloadFailed("HTTP error for \(url.lastPathComponent)")
        }

        // Move downloaded file to destination
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.moveItem(at: tempURL, to: destination)

        // Update progress (each file contributes equally)
        let progress = Double(fileIndex + 1) / Double(totalFiles)
        downloadStates[modelId] = .downloading(progress: progress)
    }

    /// Delete a downloaded model to free space
    func deleteModel(_ modelId: String) throws {
        let modelDir = modelDirectory(for: modelId)

        guard fileManager.fileExists(atPath: modelDir.path) else {
            return
        }

        try fileManager.removeItem(at: modelDir)
        downloadStates[modelId] = .notDownloaded

        // If this was the selected model, clear selection
        if selectedModelId == modelId {
            selectedModelId = nil
            userDefaults.removeObject(forKey: selectedModelKey)
        }

        print("🗑️ Model deleted: \(modelId)")
    }

    /// Select a model for use
    func selectModel(_ modelId: String) {
        guard isModelDownloaded(modelId) else {
            print("⚠️ Cannot select model that isn't downloaded: \(modelId)")
            return
        }

        selectedModelId = modelId
        userDefaults.set(modelId, forKey: selectedModelKey)

        print("✓ Selected model: \(modelId)")
    }

    /// Get the currently selected model info
    var selectedModel: ModelInfo? {
        guard let id = selectedModelId else { return nil }
        return ModelInfo.model(withId: id)
    }

    /// Cancel an ongoing download
    func cancelDownload(_ modelId: String) {
        // TODO: Implement download cancellation
        downloadStates[modelId] = .notDownloaded
    }

    /// Format bytes to human-readable size
    func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

/// Errors that can occur during model download
enum ModelDownloadError: LocalizedError {
    case downloadFailed(String)
    case invalidModel
    case insufficientSpace

    var errorDescription: String? {
        switch self {
        case .downloadFailed(let reason):
            return "Download failed: \(reason)"
        case .invalidModel:
            return "Invalid model format"
        case .insufficientSpace:
            return "Insufficient storage space"
        }
    }
}
