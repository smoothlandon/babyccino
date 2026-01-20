//
//  LLMService.swift
//  Babyccino
//
//  Protocol for LLM services (mock or real MLX)
//

import Foundation

/// Flowchart complexity classification
enum FlowchartComplexity {
    case simple    // Linear logic, max 2 decisions
    case complex   // Loops, multiple branches, recursion
}

/// Protocol for LLM inference
protocol LLMService {
    /// Generate a response to a user message
    func generateResponse(messages: [ChatMessage]) async throws -> String

    /// Classify flowchart complexity for routing decision
    func classifyFlowchartComplexity(requirements: FunctionRequirements) async throws -> FlowchartComplexity

    /// Check if the service is ready
    var isReady: Bool { get }
}

/// Represents a chat message for LLM context
struct ChatMessage {
    let role: String  // "system", "user", or "assistant"
    let content: String

    static func system(_ content: String) -> ChatMessage {
        ChatMessage(role: "system", content: content)
    }

    static func user(_ content: String) -> ChatMessage {
        ChatMessage(role: "user", content: content)
    }

    static func assistant(_ content: String) -> ChatMessage {
        ChatMessage(role: "assistant", content: content)
    }
}
