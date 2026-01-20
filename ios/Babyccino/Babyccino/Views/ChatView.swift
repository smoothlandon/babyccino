//
//  ChatView.swift
//  Babyccino
//
//  Main chat interface
//

import SwiftUI
import Combine

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var currentInput = ""
    @Published var isGenerating = false

    let serverClient: ServerClient
    let llmService: LLMService
    private let flowchartRouter: FlowchartRouter
    private var conversationHistory: [ChatMessage] = []

    init(serverClient: ServerClient, llmService: LLMService? = nil) {
        self.serverClient = serverClient
        self.llmService = llmService ?? LLMServiceFactory.createLLMService()
        self.flowchartRouter = FlowchartRouter(
            llmService: self.llmService,
            serverURL: serverClient.serverURL
        )

        // Add system prompt to conversation
        conversationHistory.append(.system("""
        You are Babyccino ☕️, a helpful assistant that helps developers design Python functions.

        Your role:
        1. Ask clarifying questions about the function requirements
        2. Discuss parameters, return types, and edge cases
        3. Once you have enough information, let the user know they can generate code

        Be conversational and helpful!
        """))

        // Add welcome message
        messages.append(Message(
            type: .assistant,
            content: "Hi! I'm Babyccino ☕️\n\nDescribe a function you'd like to build, and I'll help you design it!\n\nExample: \"I need a function that checks if a number is prime\""
        ))
    }

    func sendMessage() {
        guard !currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let userMessage = currentInput
        currentInput = ""

        // Add user message to UI and conversation history
        messages.append(Message(type: .user, content: userMessage))
        conversationHistory.append(.user(userMessage))

        Task {
            // Check if user explicitly wants to generate code (only "generate code" phrase)
            let lowercased = userMessage.lowercased()
            if lowercased.contains("generate code") || lowercased == "generate" {
                await generateCode()
            } else {
                await getAssistantResponse()
            }
        }
    }

    private func getAssistantResponse() async {
        isGenerating = true

        do {
            let response = try await llmService.generateResponse(messages: conversationHistory)

            // Check if response is a special command to show flowchart
            if response == "show_flowchart" {
                await showFlowchart()
            } else {
                // Add assistant response to UI and conversation history
                conversationHistory.append(.assistant(response))
                messages.append(Message(type: .assistant, content: response))
            }

        } catch {
            messages.append(Message(
                type: .error,
                content: "Error: \(error.localizedDescription)"
            ))
        }

        isGenerating = false
    }

    private func showFlowchart() async {
        do {
            // Extract requirements from conversation
            let requirements: FunctionRequirements
            if let mockLLM = llmService as? MockLLMService {
                requirements = mockLLM.extractRequirements()
            } else {
                // For real LLM, would parse conversation here
                requirements = createDemoRequirements()
            }

            // Use flowchart router to generate (routes to local or server based on complexity)
            let flowchart = try await flowchartRouter.generateFlowchart(requirements: requirements)

            // Add flowchart message
            messages.append(Message(
                type: .flowchart,
                content: "Here's the logic flow for \(requirements.name):",
                flowchart: flowchart
            ))

            // Add follow-up message
            conversationHistory.append(.assistant("I've created a flowchart showing the logic. Does this look correct?"))
            messages.append(Message(
                type: .assistant,
                content: "Does this flowchart capture the logic correctly?\n\nSay \"generate code\" when you're ready to generate the actual code!"
            ))

        } catch {
            messages.append(Message(
                type: .error,
                content: "Error generating flowchart: \(error.localizedDescription)"
            ))
        }
    }

    private func generateCode() async {
        isGenerating = true

        // Add thinking message
        let thinkingMessage = Message(type: .assistant, content: "Sending requirements to server...")
        messages.append(thinkingMessage)

        do {
            // Extract requirements from conversation (returns array for multi-function support)
            let requirements: [FunctionRequirements]
            if let mockLLM = llmService as? MockLLMService {
                requirements = [mockLLM.extractRequirements()]  // Single function for now
            } else {
                // For real LLM, would parse conversation here
                requirements = [createDemoRequirements()]
            }

            let response = try await serverClient.generateCode(requirements: requirements)

            // Remove thinking message
            if let index = messages.firstIndex(where: { $0.id == thinkingMessage.id }) {
                messages.remove(at: index)
            }

            // Add code result for each generated function
            for codeResult in response.results {
                messages.append(Message(
                    type: .code,
                    content: "Generated function: \(codeResult.functionName)",
                    codeResult: codeResult
                ))
            }

        } catch {
            // Remove thinking message
            if let index = messages.firstIndex(where: { $0.id == thinkingMessage.id }) {
                messages.remove(at: index)
            }

            messages.append(Message(
                type: .error,
                content: "Error: \(error.localizedDescription)"
            ))
        }

        isGenerating = false
    }

    // MARK: - Demo Helper (Remove in Phase 3C when real LLM extracts requirements)

    private func createDemoRequirements() -> FunctionRequirements {
        // This is a simplified demo - just creates a prime checker
        // In Phase 3C, the real LLM will parse conversation and extract requirements
        return FunctionRequirements(
            name: "is_prime",
            purpose: "Check if a number is prime",
            parameters: [
                FunctionParameter(name: "n", type: "int", description: "The number to check")
            ],
            returnType: "bool",
            edgeCases: [
                "n < 2 returns False",
                "n = 2 returns True",
                "Handle negative numbers"
            ],
            examples: [
                FunctionExample(input: "2", output: "True"),
                FunctionExample(input: "4", output: "False"),
                FunctionExample(input: "17", output: "True")
            ]
        )
    }
}

struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    @State private var showSettings = false

    init(serverClient: ServerClient) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(serverClient: serverClient))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.messages) { message in
                                MessageBubbleView(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding(.vertical)
                    }
                    .onChange(of: viewModel.messages.count) {
                        if let lastMessage = viewModel.messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }

                Divider()

                // Input bar
                HStack(spacing: 12) {
                    TextField("Describe a function...", text: $viewModel.currentInput, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...5)
                        .disabled(viewModel.isGenerating)

                    Button(action: viewModel.sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(canSend ? .blue : .gray)
                    }
                    .disabled(!canSend)
                }
                .padding()
            }
            .navigationTitle("Babyccino ☕️")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape")
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    ConnectionStatusView(isConnected: viewModel.serverClient.isConnected)
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(serverClient: viewModel.serverClient)
            }
        }
        .navigationViewStyle(.stack)
    }

    private var canSend: Bool {
        !viewModel.currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isGenerating
    }
}

struct ConnectionStatusView: View {
    let isConnected: Bool

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isConnected ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            Text(isConnected ? "Connected" : "Disconnected")
                .font(.caption)
        }
    }
}
