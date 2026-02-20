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

    // Test approval flow state
    @Published var pendingTestApproval: GenerateTestsResponse? = nil
    private var pendingRequirements: [FunctionRequirements]? = nil

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

        // Check if LLM is ready, add loading message if not
        Task { [weak self] in
            guard let self else { return }
            let service = self.llmService

            // Wait a moment for initialization to complete
            try? await Task.sleep(for: .seconds(1))
            if !service.isReady {
                await MainActor.run {
                    self.messages.append(Message(
                        type: .assistant,
                        content: "⏳ Loading AI model... This takes 10-20 seconds on first launch. Please wait before sending messages."
                    ))
                }

                // Poll for readiness and remove message when ready
                while !service.isReady {
                    try? await Task.sleep(for: .seconds(2))
                }

                await MainActor.run {
                    // Remove loading message
                    if let loadingIndex = self.messages.firstIndex(where: { $0.content.contains("Loading AI model") }) {
                        self.messages.remove(at: loadingIndex)
                    }
                    // Add ready message
                    self.messages.append(Message(
                        type: .assistant,
                        content: "✅ AI model ready! You can now start chatting."
                    ))
                }
            }
        }
    }

    func sendMessage() {
        guard !currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let userMessage = currentInput
        currentInput = ""

        print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("💬 [ChatViewModel] sendMessage() called")
        print("📝 [ChatViewModel] User message: \"\(userMessage)\"")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        // Add user message to UI and conversation history
        messages.append(Message(type: .user, content: userMessage))
        conversationHistory.append(.user(userMessage))
        print("📊 [ChatViewModel] Conversation now has \(conversationHistory.count) messages")

        Task {
            // Check if user explicitly wants to generate code (only "generate code" phrase)
            let lowercased = userMessage.lowercased()
            if lowercased.contains("generate code") || lowercased == "generate" {
                print("🎯 [ChatViewModel] Detected GENERATE CODE command")
                await generateCode()
            } else {
                print("💭 [ChatViewModel] Getting assistant response")
                await getAssistantResponse()
            }
        }
    }

    private func getAssistantResponse() async {
        print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🔄 [ChatViewModel] getAssistantResponse() called")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        isGenerating = true

        do {
            print("📞 [ChatViewModel] Calling llmService.generateResponse()")
            let response = try await llmService.generateResponse(messages: conversationHistory)
            print("✅ [ChatViewModel] Got response: \"\(response)\"")

            // Check if response is a special command
            if response == "show_flowchart" {
                print("🎯 [ChatViewModel] Response is SHOW_FLOWCHART command")
                await showFlowchart()
            } else if response == "generate_code" {
                print("🎯 [ChatViewModel] Response is GENERATE_CODE command")
                await generateCode()
            } else {
                print("💬 [ChatViewModel] Normal response, adding to conversation")
                // Add assistant response to UI and conversation history
                conversationHistory.append(.assistant(response))
                messages.append(Message(type: .assistant, content: response))
                print("📊 [ChatViewModel] Conversation now has \(conversationHistory.count) messages")
            }

            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

        } catch {
            print("❌ [ChatViewModel] Error: \(error.localizedDescription)")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
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

            #if targetEnvironment(simulator)
            // Simulator: only MockLLMService available
            if let mockLLM = llmService as? MockLLMService {
                requirements = mockLLM.extractRequirements()
            } else {
                requirements = createDemoRequirements()
            }
            #else
            // Physical device: MLXLLMService available
            if let mockLLM = llmService as? MockLLMService {
                requirements = mockLLM.extractRequirements()
            } else if let mlxLLM = llmService as? MLXLLMService {
                requirements = mlxLLM.extractRequirements()
            } else {
                requirements = createDemoRequirements()
            }
            #endif

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

    /// Step 1: Extract requirements, ask server to propose test cases, show approval sheet
    private func generateCode() async {
        print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🔧 [ChatViewModel] generateCode() called — starting test proposal flow")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        isGenerating = true

        let thinkingMessage = Message(type: .assistant, content: "⏳ Generating test cases for your review...")
        messages.append(thinkingMessage)

        do {
            // Extract requirements from conversation
            let requirements: [FunctionRequirements]

            #if targetEnvironment(simulator)
            if let mockLLM = llmService as? MockLLMService {
                requirements = [mockLLM.extractRequirements()]
            } else {
                requirements = [createDemoRequirements()]
            }
            #else
            if let mockLLM = llmService as? MockLLMService {
                requirements = [mockLLM.extractRequirements()]
            } else if let mlxLLM = llmService as? MLXLLMService {
                requirements = [mlxLLM.extractRequirements()]
            } else {
                requirements = [createDemoRequirements()]
            }
            #endif

            let req = requirements[0]
            print("📋 [ChatViewModel] Requirements extracted:")
            print("   name: \(req.name)")
            print("   purpose: \(req.purpose)")
            print("   return_type: \(req.returnType)")
            print("   parameters: \(req.parameters.map { "\($0.name): \($0.type)" })")
            print("   edge_cases: \(req.edgeCases)")
            print("   transcript chars: \(req.conversationTranscript?.count ?? 0)")

            // Log the full JSON being sent to server
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            if let reqData = try? encoder.encode(req),
               let reqStr = String(data: reqData, encoding: .utf8) {
                print("📤 [ChatViewModel] Sending to /generate-tests:")
                print("   \(reqStr)")
            }

            print("🌐 [ChatViewModel] Calling serverClient.generateTests()...")

            // Ask server to propose test cases based on the requirements + transcript
            let testResponse = try await serverClient.generateTests(requirements: req)

            print("✅ [ChatViewModel] Got \(testResponse.proposedTests.count) proposed test cases:")
            for (i, t) in testResponse.proposedTests.enumerated() {
                print("   [\(i)] \(t.description): \(req.name)(\(t.input)) == \(t.expectedOutput) [edge:\(t.isEdgeCase)]")
            }

            // Remove thinking message
            if let index = messages.firstIndex(where: { $0.id == thinkingMessage.id }) {
                messages.remove(at: index)
            }

            print("📋 [ChatViewModel] Setting pendingTestApproval — sheet should appear")

            // Store requirements for step 2, show approval sheet
            pendingRequirements = requirements
            pendingTestApproval = testResponse

            print("✅ [ChatViewModel] pendingTestApproval set, pendingRequirements set")

        } catch {
            print("❌ [ChatViewModel] generateCode error: \(error)")
            if let index = messages.firstIndex(where: { $0.id == thinkingMessage.id }) {
                messages.remove(at: index)
            }
            messages.append(Message(type: .error, content: "Error generating tests: \(error.localizedDescription)"))
        }

        isGenerating = false
        print("🔧 [ChatViewModel] generateCode() complete, isGenerating=false")
    }

    /// Step 2: Called after user approves test cases — generate code targeting those tests
    func generateCodeWithApprovedTests(_ approvedTests: [ApprovedTestCase]) async {
        print("🔧 [ChatViewModel] generateCodeWithApprovedTests() called with \(approvedTests.count) tests")
        for (i, t) in approvedTests.enumerated() {
            print("   [\(i)] \(t.description): input=\(t.input) expected=\(t.expectedOutput)")
        }

        guard let requirements = pendingRequirements else {
            print("❌ [ChatViewModel] pendingRequirements is nil — cannot generate code")
            messages.append(Message(type: .error, content: "Error: requirements missing"))
            return
        }
        pendingRequirements = nil

        print("🔧 [ChatViewModel] generateCodeWithApprovedTests() — \(approvedTests.count) approved tests")

        isGenerating = true

        let thinkingMessage = Message(type: .assistant, content: "⏳ Generating code...")
        messages.append(thinkingMessage)

        do {
            let response = try await serverClient.generateCode(
                requirements: requirements,
                approvedTests: approvedTests
            )
            print("✅ [ChatViewModel] Got \(response.results.count) code result(s) from server")

            if let index = messages.firstIndex(where: { $0.id == thinkingMessage.id }) {
                messages.remove(at: index)
            }

            for codeResult in response.results {
                messages.append(Message(
                    type: .code,
                    content: "Generated function: \(codeResult.functionName)",
                    codeResult: codeResult
                ))
            }

        } catch {
            if let index = messages.firstIndex(where: { $0.id == thinkingMessage.id }) {
                messages.remove(at: index)
            }
            messages.append(Message(type: .error, content: "Error: \(error.localizedDescription)"))
        }

        isGenerating = false
    }

    /// Called when user cancels test approval
    func cancelTestApproval() {
        pendingTestApproval = nil
        pendingRequirements = nil
        messages.append(Message(
            type: .assistant,
            content: "Cancelled. You can adjust your requirements and say 'generate code' again."
        ))
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
            ],
            conversationTranscript: nil
        )
    }
}

struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    @State private var showSettings = false
    @State private var showCopiedConfirmation = false
    @State private var showTestApproval = false

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
                    HStack(spacing: 16) {
                        Button(action: copyConversation) {
                            Image(systemName: showCopiedConfirmation ? "checkmark" : "doc.on.clipboard")
                                .foregroundColor(showCopiedConfirmation ? .green : .primary)
                                .animation(.easeInOut(duration: 0.2), value: showCopiedConfirmation)
                        }
                        Button(action: { showSettings = true }) {
                            Image(systemName: "gearshape")
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    ConnectionStatusView(isConnected: viewModel.serverClient.isConnected)
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(serverClient: viewModel.serverClient)
            }
            .sheet(isPresented: $showTestApproval, onDismiss: {
                print("🗂️ [ChatView] Test approval sheet dismissed")
                // Only cancel if user dismissed without approving (pendingTestApproval still set)
                if viewModel.pendingTestApproval != nil {
                    print("🗂️ [ChatView] pendingTestApproval still set — treating as cancel")
                    viewModel.cancelTestApproval()
                } else {
                    print("🗂️ [ChatView] pendingTestApproval already nil — approved path, no cancel")
                }
            }) {
                if let testResponse = viewModel.pendingTestApproval {
                    TestApprovalView(
                        functionName: testResponse.functionName,
                        proposedTests: testResponse.proposedTests,
                        onApprove: { approvedTests in
                            print("🗂️ [ChatView] User approved \(approvedTests.count) tests — dismissing sheet")
                            // Clear pending so onDismiss doesn't cancel, then dismiss
                            viewModel.pendingTestApproval = nil
                            showTestApproval = false
                            Task { await viewModel.generateCodeWithApprovedTests(approvedTests) }
                        },
                        onCancel: {
                            print("🗂️ [ChatView] User cancelled test approval")
                            showTestApproval = false
                            // onDismiss will call cancelTestApproval()
                        }
                    )
                } else {
                    // Sheet was presented but pendingTestApproval became nil — shouldn't normally happen
                    let _ = print("⚠️ [ChatView] Sheet presented but pendingTestApproval is nil")
                    EmptyView()
                }
            }
            .onChange(of: viewModel.pendingTestApproval != nil) { _, hasPending in
                print("🔄 [ChatView] pendingTestApproval changed — hasPending=\(hasPending), showTestApproval=\(showTestApproval)")
                if hasPending && !showTestApproval {
                    print("🔄 [ChatView] Showing test approval sheet")
                    showTestApproval = true
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private var canSend: Bool {
        !viewModel.currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isGenerating
    }

    private func copyConversation() {
        let lines = viewModel.messages.compactMap { message -> String? in
            switch message.type {
            case .user:
                return "You: \(message.content)"
            case .assistant:
                return "Babyccino: \(message.content)"
            case .code:
                if let code = message.codeResult {
                    return "Code (\(code.functionName)):\n```python\n\(code.function)\n```"
                }
                return nil
            case .flowchart, .error:
                return nil
            }
        }

        let transcript = lines.joined(separator: "\n\n")
        UIPasteboard.general.string = transcript

        showCopiedConfirmation = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run { showCopiedConfirmation = false }
        }
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
