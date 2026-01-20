//
//  MLXLLMService.swift
//  Babyccino
//
//  Real LLM using MLX Swift (device-only)
//  Only compiles and links on physical devices, not simulator
//

import Foundation

// Only compile MLX code for physical devices
#if !targetEnvironment(simulator)
import MLX
import MLXNN
import MLXRandom
import MLXFast
import MLXLinalg

class MLXLLMService: LLMService {
    var isReady: Bool = false

    // TODO: Phase 3C - Implement MLX-based inference
    // Will load a quantized model suitable for iPad M3 (e.g., Phi-3 or Qwen 1.8B)

    init() {
        // TODO: Load model weights
        // TODO: Initialize MLX context
    }

    func generateResponse(messages: [ChatMessage]) async throws -> String {
        // TODO: Implement MLX inference
        // For now, throw error
        throw NSError(
            domain: "MLXLLMService",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "MLX service not yet implemented"]
        )
    }
}
#endif
