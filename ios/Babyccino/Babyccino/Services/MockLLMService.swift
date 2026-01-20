//
//  MockLLMService.swift
//  Babyccino
//
//  Mock LLM for simulator testing
//

import Foundation

class MockLLMService: LLMService {
    var isReady: Bool = true

    private var conversationState: ConversationState = .initial

    enum ConversationState {
        case initial
        case askedForDetails
        case hasRequirements
        case showedFlowchart
    }

    func generateResponse(messages: [ChatMessage]) async throws -> String {
        // Simulate thinking delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        guard let lastUserMessage = messages.last(where: { $0.role == "user" }) else {
            return "I didn't receive a message. Could you try again?"
        }

        let userMessage = lastUserMessage.content.lowercased()

        // State machine for mock conversation
        switch conversationState {
        case .initial:
            conversationState = .askedForDetails
            return """
            Great! I'd love to help you create that function.

            Let me ask a few clarifying questions:

            1. What should the function return when given invalid input?
            2. Should it handle negative numbers? If so, how?
            3. Do you need it optimized for very large inputs?
            4. What should happen with edge cases like 0 or 1?

            Please provide any specific requirements you have in mind.
            """

        case .askedForDetails:
            if userMessage.contains("generate") || userMessage.contains("code") || userMessage.contains("ready") {
                conversationState = .hasRequirements
                return """
                Perfect! I have everything I need.

                Based on our conversation, I'll create a function that:
                • Checks if a number is prime
                • Returns False for numbers less than 2
                • Handles negative numbers by returning False
                • Is optimized using square root optimization

                Say "generate code" when you're ready for me to send this to the server!
                """
            } else {
                conversationState = .hasRequirements
                return """
                Thanks for those details! I now have a clear picture of what you need.

                I'll create a well-documented function with:
                • Proper type hints
                • Edge case handling as discussed
                • Clear docstrings
                • Comprehensive unit tests

                When you're ready, just say "generate code" and I'll send the requirements to the server!
                """
            }

        case .hasRequirements:
            if userMessage.contains("show") && (userMessage.contains("flow") || userMessage.contains("visualize")) {
                conversationState = .showedFlowchart
                return "show_flowchart" // Special signal for ChatView
            } else {
                return """
                I have the requirements ready!

                Say "show me the flow" to visualize the logic, or "generate code" to proceed directly to code generation.
                """
            }

        case .showedFlowchart:
            return """
            Does this flowchart capture the logic correctly?

            Say "generate code" when you're ready to generate the actual code!
            """
        }
    }

    /// Extract requirements from conversation (mock implementation)
    func extractRequirements() -> FunctionRequirements {
        // Mock extraction - in real version, this would parse conversation
        return FunctionRequirements(
            name: "is_prime",
            purpose: "Check if a number is prime",
            parameters: [
                FunctionParameter(
                    name: "n",
                    type: "int",
                    description: "The number to check for primality"
                )
            ],
            returnType: "bool",
            edgeCases: [
                "n < 2 returns False",
                "n = 2 returns True",
                "Handle negative numbers by returning False"
            ],
            examples: [
                FunctionExample(input: "2", output: "True"),
                FunctionExample(input: "4", output: "False"),
                FunctionExample(input: "17", output: "True"),
                FunctionExample(input: "1", output: "False")
            ]
        )
    }

    /// Generate a mock flowchart for the prime checker
    func generateFlowchart() -> Flowchart {
        return Flowchart(
            nodes: [
                FlowchartNode(id: "start", type: .start, label: "Start", x: 200, y: 50),
                FlowchartNode(id: "input", type: .input, label: "Input: n", x: 200, y: 150),
                FlowchartNode(id: "check_less_2", type: .decision, label: "n < 2?", x: 200, y: 270),
                FlowchartNode(id: "return_false_1", type: .end, label: "Return False", x: 50, y: 390),
                FlowchartNode(id: "check_equals_2", type: .decision, label: "n == 2?", x: 200, y: 390),
                FlowchartNode(id: "return_true", type: .end, label: "Return True", x: 350, y: 510),
                FlowchartNode(id: "loop_check", type: .process, label: "Check divisibility\n(i = 2 to √n)", x: 200, y: 510),
                FlowchartNode(id: "divisible", type: .decision, label: "n % i == 0?", x: 200, y: 630),
                FlowchartNode(id: "return_false_2", type: .end, label: "Return False", x: 50, y: 750),
                FlowchartNode(id: "return_true_2", type: .end, label: "Return True", x: 200, y: 750)
            ],
            edges: [
                FlowchartEdge(id: "e1", from: "start", to: "input"),
                FlowchartEdge(id: "e2", from: "input", to: "check_less_2"),
                FlowchartEdge(id: "e3", from: "check_less_2", to: "return_false_1", label: "Yes"),
                FlowchartEdge(id: "e4", from: "check_less_2", to: "check_equals_2", label: "No"),
                FlowchartEdge(id: "e5", from: "check_equals_2", to: "return_true", label: "Yes"),
                FlowchartEdge(id: "e6", from: "check_equals_2", to: "loop_check", label: "No"),
                FlowchartEdge(id: "e7", from: "loop_check", to: "divisible"),
                FlowchartEdge(id: "e8", from: "divisible", to: "return_false_2", label: "Yes"),
                FlowchartEdge(id: "e9", from: "divisible", to: "return_true_2", label: "No")
            ],
            title: "Prime Number Check Algorithm",
            description: "Checks if a number is prime using trial division with square root optimization"
        )
    }

    /// Reset conversation state
    func resetConversation() {
        conversationState = .initial
    }
}
