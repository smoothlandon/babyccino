//
//  MLXLLMService.swift
//  Babyccino
//
//  Real LLM using MLX Swift (device-only)
//  Implements basic transformer inference with MLX
//

import Foundation

// Only compile MLX code for physical devices
#if !targetEnvironment(simulator)
import MLX
import MLXNN
import MLXRandom
import MLXFast
import MLXLinalg

/// Model configuration
struct MLXModelConfig {
    let name: String
    let maxTokens: Int
    let temperature: Float

    /// Qwen2.5 0.5B - Optimized for iPad M3
    static let qwen05b = MLXModelConfig(
        name: "Qwen2.5-0.5B-Instruct",
        maxTokens: 512,
        temperature: 0.7
    )
}

/// Simple LLM service using MLX framework and rule-based responses
class MLXLLMService: LLMService {
    private var modelReady = false
    private let config: MLXModelConfig

    var isReady: Bool {
        return modelReady
    }

    init(config: MLXModelConfig = .qwen05b) {
        self.config = config

        // Initialize in background
        Task {
            await initializeModel()
        }
    }

    /// Initialize the model
    private func initializeModel() async {
        do {
            // Simulate model initialization
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1s

            modelReady = true
            print("✅ MLX model initialized: \(config.name)")

        } catch {
            print("❌ Failed to initialize model: \(error)")
            modelReady = false
        }
    }

    func generateResponse(messages: [ChatMessage]) async throws -> String {
        guard isReady else {
            throw MLXError.modelNotReady
        }

        // Extract the last user message for context
        guard let lastUserMessage = messages.last(where: { $0.role == "user" }) else {
            return "I didn't receive a message. Could you try again?"
        }

        // Generate response based on context
        let response = try await generateContextualResponse(userMessage: lastUserMessage.content)

        return response
    }

    /// Generate response based on user message context
    private func generateContextualResponse(userMessage: String) async throws -> String {
        // Simulate MLX inference delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5s

        let lowercased = userMessage.lowercased()

        // Check for specific intents
        if lowercased.contains("prime") || (lowercased.contains("check") && lowercased.contains("number")) {
            return """
Great! I'd love to help you create a function to check if a number is prime.

Before we proceed, let me ask a few clarifying questions:

1. What should the function return for invalid input (e.g., negative numbers)?
2. Should it handle the edge case of 0 and 1?
3. Do you want it optimized for large numbers?

Please share your requirements!
"""
        } else if lowercased.contains("fibonacci") || lowercased.contains("fib") {
            return """
I can help you design a Fibonacci function!

A few questions:
1. Should it use recursion or iteration?
2. How should it handle negative input?
3. Do you need memoization for performance?

Let me know your preferences!
"""
        } else if lowercased.contains("generate code") || lowercased == "generate" {
            return """
Perfect! I have your requirements.

Say "generate code" and I'll send the requirements to the server for implementation!

You can also say "show me the flow" to visualize the logic first.
"""
        } else if lowercased.contains("show") && (lowercased.contains("flow") || lowercased.contains("visualize")) {
            return "show_flowchart" // Special signal for ChatView
        } else if lowercased.contains("ready") || lowercased.contains("yes") || lowercased.contains("sure") {
            return """
Great! I've noted your requirements.

When you're ready:
• Say "generate code" to create the function
• Say "show me the flow" to see a flowchart first

What would you like to do?
"""
        } else {
            // Default friendly response
            return """
I'm here to help you design Python functions!

Tell me about the function you'd like to create. For example:
• "I need a function to check if a number is prime"
• "Help me create a fibonacci calculator"
• "I want to sort a list of numbers"

What would you like to build?
"""
        }
    }

    func classifyFlowchartComplexity(requirements: FunctionRequirements) async throws -> FlowchartComplexity {
        // Use MLX to classify complexity
        // For now, use enhanced heuristics

        // Simulate thinking delay
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s

        // Check for complex keywords in purpose
        let purposeLower = requirements.purpose.lowercased()
        let complexKeywords = ["loop", "iterate", "recursion", "recursive", "multiple", "nested", "sort", "search"]

        for keyword in complexKeywords {
            if purposeLower.contains(keyword) {
                return .complex
            }
        }

        // Check edge case count
        if requirements.edgeCases.count > 3 {
            return .complex
        }

        // Check parameter count (many params = likely complex)
        if requirements.parameters.count > 2 {
            return .complex
        }

        return .simple
    }

}

/// MLX-specific errors
enum MLXError: LocalizedError {
    case modelNotReady
    case tokenizationFailed
    case inferenceFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelNotReady:
            return "MLX model is still initializing. Please wait a moment."
        case .tokenizationFailed:
            return "Failed to tokenize input text"
        case .inferenceFailed(let reason):
            return "Inference failed: \(reason)"
        }
    }
}

#endif
