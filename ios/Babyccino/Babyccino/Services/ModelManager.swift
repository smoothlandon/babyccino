//
//  ModelManager.swift
//  Babyccino
//
//  Manages model downloads, caching, and selection
//

import Foundation
import Combine

#if !targetEnvironment(simulator)
import MLXLLM
import MLXLMCommon
#endif

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

    /// Get the directory for a specific model (used by MLXLLMService)
    func modelDirectory(for modelId: String) -> URL {
        // MLX models are stored in Hub cache, not our custom directory
        // The LLMModelFactory handles the actual location
        // This is just for backwards compatibility
        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return cacheDir.appendingPathComponent("models", isDirectory: true).appendingPathComponent(modelId, isDirectory: true)
    }

    /// Check if a model is downloaded
    /// For now, we track this via download state rather than filesystem checks
    /// since LLMModelFactory manages its own Hub cache
    func isModelDownloaded(_ modelId: String) -> Bool {
        if case .downloaded = downloadStates[modelId] {
            return true
        }
        return false
    }

    /// Get the size of a downloaded model in bytes
    /// Note: Size estimation since models are in Hub cache
    func modelSize(for modelId: String) -> Int64? {
        guard isModelDownloaded(modelId) else { return nil }
        // Return the model's declared size from ModelInfo
        if let modelInfo = ModelInfo.model(withId: modelId) {
            return Int64(modelInfo.sizeInMB) * 1024 * 1024
        }
        return nil
    }

    /// Update download states for all models
    func updateDownloadStates() async {
        // Check if we have a selected model - if so, mark it as downloaded
        if let selectedId = selectedModelId {
            downloadStates[selectedId] = .downloaded
            print("✓ Restored downloaded model: \(selectedId)")
        }

        // Initialize states for other models
        for model in ModelInfo.availableModels {
            if downloadStates[model.id] == nil {
                downloadStates[model.id] = .notDownloaded
            }
        }
    }

    /// Download a model from HuggingFace using MLX's built-in Hub API
    func downloadModel(_ modelInfo: ModelInfo) async throws {
        #if targetEnvironment(simulator)
        // Simulator doesn't support MLX
        throw ModelDownloadError.downloadFailed("Models can only be downloaded on physical devices")
        #else

        print("🚀 Starting download for: \(modelInfo.displayName)")
        print("   Repo: \(modelInfo.huggingFaceRepo)")
        print("   Size: \(modelInfo.sizeInMB) MB")

        // Set downloading state
        downloadStates[modelInfo.id] = .downloading(progress: 0.0)

        do {
            // Create model configuration
            let modelConfiguration = ModelConfiguration(
                id: modelInfo.huggingFaceRepo,
                defaultPrompt: "You are a helpful assistant"
            )

            // Use LLMModelFactory to download the model
            // This handles all HuggingFace complexity (auth, redirects, caching, etc.)
            print("📥 Loading model via Hub API (this will download if needed)...")

            let factory = LLMModelFactory.shared
            let startTime = Date()

            _ = try await factory.loadContainer(configuration: modelConfiguration) { [weak self] progress in
                Task { @MainActor in
                    let percent = Int(progress.fractionCompleted * 100)
                    self?.downloadStates[modelInfo.id] = .downloading(progress: progress.fractionCompleted)

                    // Log progress every 10%
                    if percent % 10 == 0 {
                        print("📊 Progress: \(percent)% - \(progress.localizedDescription ?? "")")
                    }
                }
            }

            let elapsed = Date().timeIntervalSince(startTime)
            print("✅ Model downloaded in \(String(format: "%.1f", elapsed))s")

            // Mark as downloaded
            downloadStates[modelInfo.id] = .downloaded

            print("✅ Model ready: \(modelInfo.displayName)")

        } catch {
            print("❌ Download failed: \(error)")
            print("   Error type: \(type(of: error))")
            print("   Description: \(error.localizedDescription)")
            downloadStates[modelInfo.id] = .failed(error: error.localizedDescription)
            throw error
        }
        #endif
    }


    /// Delete a downloaded model to free space
    /// Note: Models are managed by Hub cache, so we just update state
    func deleteModel(_ modelId: String) throws {
        downloadStates[modelId] = .notDownloaded

        // If this was the selected model, clear selection
        if selectedModelId == modelId {
            selectedModelId = nil
            userDefaults.removeObject(forKey: selectedModelKey)
        }

        print("🗑️ Model marked as deleted: \(modelId)")
        print("⚠️ Note: To fully remove, clear Hub cache via system settings")
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
