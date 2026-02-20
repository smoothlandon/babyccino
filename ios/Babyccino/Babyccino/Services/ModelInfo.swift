//
//  ModelInfo.swift
//  Babyccino
//
//  Defines available LLM models for on-device inference
//

import Foundation

/// Information about an available LLM model
struct ModelInfo: Identifiable, Codable {
    let id: String
    let name: String
    let displayName: String
    let huggingFaceRepo: String
    let sizeInMB: Int
    let quality: Int  // 1-5 stars
    let speed: ModelSpeed
    let description: String

    enum ModelSpeed: String, Codable {
        case fast = "Fast"
        case medium = "Medium"
        case slow = "Slow"
    }

    /// Available models for download
    /// Only models that support structured JSON output reliably
    static let availableModels: [ModelInfo] = [
        ModelInfo(
            id: "qwen-1.5b",
            name: "Qwen2.5-1.5B-Instruct-4bit",
            displayName: "Qwen 1.5B (Recommended)",
            huggingFaceRepo: "mlx-community/Qwen2.5-1.5B-Instruct-4bit",
            sizeInMB: 900,
            quality: 4,
            speed: .medium,
            description: "Best balance of speed and quality. Reliable JSON output for structured responses. ~30 tokens/sec on iPad M3."
        ),
        ModelInfo(
            id: "phi-3-mini",
            name: "Phi-3-mini-4k-instruct-4bit",
            displayName: "Phi-3 Mini 3.8B",
            huggingFaceRepo: "mlx-community/Phi-3-mini-4k-instruct-4bit",
            sizeInMB: 2300,
            quality: 5,
            speed: .slow,
            description: "Highest quality. Excellent reasoning and most reliable JSON generation. ~15 tokens/sec on iPad M3."
        )
    ]

    /// Get model by ID
    static func model(withId id: String) -> ModelInfo? {
        return availableModels.first { $0.id == id }
    }
}

/// Download state for a model
enum ModelDownloadState: Equatable {
    case notDownloaded
    case downloading(progress: Double)
    case downloaded
    case failed(error: String)

    var isDownloading: Bool {
        if case .downloading = self {
            return true
        }
        return false
    }
}
