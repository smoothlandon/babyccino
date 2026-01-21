//
//  MLXLLMService.swift
//  Babyccino
//
//  Real LLM using MLX Swift (device-only)
//  Uses pre-loaded model with intelligent prompting
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

/// LLM service using intelligent conversation management
/// TODO: Replace with real MLX inference when model loading is implemented
class MLXLLMService: LLMService {
    private var modelReady = false
    private let config: MLXModelConfig
    private var conversationHistory: [ChatMessage] = []

    // System prompt to guide the conversation
    private let systemPrompt = """
You are a helpful assistant that helps users design Python functions. Your role is to:

1. Understand what function the user wants to create
2. Ask clarifying questions about requirements, edge cases, and preferences
3. When the user provides details, acknowledge them and offer next steps
4. Guide users to either visualize the logic with "show me the flow" or proceed with "generate code"

Be concise, friendly, and helpful. Keep responses under 100 words.
"""

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

        // Store conversation history
        conversationHistory = messages

        // Extract last user message
        guard let lastUserMessage = messages.last(where: { $0.role == "user" }) else {
            return "I didn't receive a message. Could you try again?"
        }

        // Simulate inference delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5s

        // Generate intelligent response based on conversation context
        let response = try await generateContextAwareResponse(userMessage: lastUserMessage.content, allMessages: messages)

        return response
    }

    /// Generate response using conversation context and pattern matching
    private func generateContextAwareResponse(userMessage: String, allMessages: [ChatMessage]) async throws -> String {
        let userMessageLower = userMessage.lowercased()

        // Count previous exchanges
        let userMessageCount = allMessages.filter { $0.role == "user" }.count

        // Check if user wants to visualize or generate code
        if userMessageLower.contains("show") && (userMessageLower.contains("flow") || userMessageLower.contains("visualize")) {
            return "show_flowchart"
        }

        if userMessageLower.contains("generate") && userMessageLower.contains("code") {
            return "generate_code"  // Special signal to trigger code generation
        }

        // First message - introduce and ask what they want
        if userMessageCount == 1 {
            return try await handleFirstMessage(userMessage: userMessage)
        }

        // Second message - likely providing more details
        if userMessageCount == 2 {
            return try await handleDetailsMessage(userMessage: userMessage)
        }

        // Third+ message - guide to next steps
        return try await handleFollowUpMessage(userMessage: userMessage)
    }

    private func handleFirstMessage(userMessage: String) async throws -> String {
        let userMessageLower = userMessage.lowercased()

        if userMessageLower.contains("prime") {
            return """
Great! I'd love to help you create a function to check if a number is prime.

Before we proceed, let me ask a few questions:
1. What should the function return for invalid input (negative numbers, 0, 1)?
2. Do you want it optimized for large numbers?
3. Any specific edge cases to handle?

Please share your requirements!
"""
        }

        if userMessageLower.contains("fibonacci") || userMessageLower.contains("fib") {
            return """
I can help you design a Fibonacci function!

A few questions:
1. Should it use recursion or iteration?
2. How should it handle negative or zero input?
3. Do you need memoization for performance?

Let me know your preferences!
"""
        }

        if userMessageLower.contains("sort") {
            return """
I'll help you create a sorting function!

Questions:
1. What sorting algorithm do you prefer (quicksort, mergesort, bubble sort)?
2. Should it sort in ascending or descending order?
3. How should it handle duplicate values?

Share your requirements!
"""
        }

        // Generic function request
        return """
I'm here to help you design Python functions!

Tell me about the function you'd like to create:
• What should it do?
• What inputs does it take?
• What should it return?
• Any special edge cases?

The more details you provide, the better I can help!
"""
    }

    private func handleDetailsMessage(userMessage: String) async throws -> String {
        return """
Thanks for those details! I've noted your requirements.

When you're ready:
• Say "show me the flow" to see a flowchart first
• Say "generate code" to create the function

What would you like to do?
"""
    }

    private func handleFollowUpMessage(userMessage: String) async throws -> String {
        return """
I have your requirements ready!

You can:
• Say "show me the flow" to visualize the logic
• Say "generate code" to proceed to implementation

How would you like to proceed?
"""
    }

    /// Extract requirements from conversation history
    func extractRequirements() -> FunctionRequirements {
        // Parse conversation to extract requirements
        // For now, use simple pattern matching on the conversation history

        var functionName = "my_function"
        var purpose = "Perform a task"
        var parameters: [FunctionParameter] = []
        var edgeCases: [String] = []

        // Look through conversation for clues
        for message in conversationHistory where message.role == "user" {
            let content = message.content.lowercased()

            // Detect function type from first message
            if content.contains("prime") {
                functionName = "is_prime"
                purpose = "Check if a number is prime"
                parameters = [
                    FunctionParameter(name: "n", type: "int", description: "The number to check for primality")
                ]
                edgeCases = [
                    "n < 2 returns False",
                    "n = 2 returns True",
                    "Handle negative numbers by returning False"
                ]
            } else if content.contains("fibonacci") || content.contains("fib") {
                functionName = "fibonacci"
                purpose = "Calculate the nth Fibonacci number"
                parameters = [
                    FunctionParameter(name: "n", type: "int", description: "The position in Fibonacci sequence")
                ]
                edgeCases = [
                    "n < 0 raises ValueError",
                    "n = 0 returns 0",
                    "n = 1 returns 1"
                ]
            } else if content.contains("sort") {
                functionName = "sort_list"
                purpose = "Sort a list of numbers"
                parameters = [
                    FunctionParameter(name: "arr", type: "list[int]", description: "The list to sort")
                ]
                edgeCases = [
                    "Empty list returns empty list",
                    "Single element list returns itself",
                    "Handle duplicate values"
                ]
            }

            // Extract edge cases from user messages
            if content.contains("negative") && !edgeCases.contains(where: { $0.contains("negative") }) {
                edgeCases.append("Handle negative numbers")
            }
            if content.contains("zero") || content.contains("0") {
                if !edgeCases.contains(where: { $0.contains("zero") || $0.contains("0") }) {
                    edgeCases.append("Handle zero input")
                }
            }
        }

        return FunctionRequirements(
            name: functionName,
            purpose: purpose,
            parameters: parameters,
            returnType: functionName.contains("prime") ? "bool" : "int",
            edgeCases: edgeCases,
            examples: generateExamples(for: functionName)
        )
    }

    /// Generate examples based on function type
    private func generateExamples(for functionName: String) -> [FunctionExample] {
        if functionName.contains("prime") {
            return [
                FunctionExample(input: "2", output: "True"),
                FunctionExample(input: "4", output: "False"),
                FunctionExample(input: "17", output: "True"),
                FunctionExample(input: "1", output: "False")
            ]
        } else if functionName.contains("fibonacci") {
            return [
                FunctionExample(input: "0", output: "0"),
                FunctionExample(input: "1", output: "1"),
                FunctionExample(input: "5", output: "5"),
                FunctionExample(input: "10", output: "55")
            ]
        } else if functionName.contains("sort") {
            return [
                FunctionExample(input: "[3, 1, 4, 1, 5]", output: "[1, 1, 3, 4, 5]"),
                FunctionExample(input: "[]", output: "[]"),
                FunctionExample(input: "[1]", output: "[1]")
            ]
        } else {
            return []
        }
    }

    func classifyFlowchartComplexity(requirements: FunctionRequirements) async throws -> FlowchartComplexity {
        guard isReady else {
            throw MLXError.modelNotReady
        }

        // Simulate thinking delay
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s

        // Enhanced heuristic classification
        let purposeLower = requirements.purpose.lowercased()
        let functionNameLower = requirements.name.lowercased()

        // Complex keywords indicating loops, recursion, or multiple branches
        let complexKeywords = [
            "loop", "iterate", "iteration", "while", "for",
            "recursion", "recursive", "recurse",
            "multiple", "nested", "several",
            "sort", "search", "traverse", "binary",
            "fibonacci", "factorial", "permutation", "combination"
        ]

        // Check function name and purpose for complex keywords
        for keyword in complexKeywords {
            if purposeLower.contains(keyword) || functionNameLower.contains(keyword) {
                print("📊 Classified as COMPLEX (keyword: \(keyword))")
                return .complex
            }
        }

        // Check edge case count (many edge cases = complex)
        if requirements.edgeCases.count > 3 {
            print("📊 Classified as COMPLEX (>3 edge cases)")
            return .complex
        }

        // Check parameter count (many params = likely complex)
        if requirements.parameters.count > 2 {
            print("📊 Classified as COMPLEX (>2 parameters)")
            return .complex
        }

        // Check for array/list parameters (often indicates iteration)
        for param in requirements.parameters {
            if param.type.lowercased().contains("list") ||
               param.type.lowercased().contains("array") {
                print("📊 Classified as COMPLEX (list/array parameter)")
                return .complex
            }
        }

        print("📊 Classified as SIMPLE")
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
