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

    init(serverClient: ServerClient) {
        self.serverClient = serverClient

        // Add welcome message
        messages.append(Message(
            type: .assistant,
            content: "Hi! I'm Babyccino ☕️\n\nFor this demo, describe the function you want and I'll send it to the server for code generation.\n\nExample: \"I need a function that checks if a string is a palindrome, ignoring case and spaces\""
        ))
    }

    func sendMessage() {
        guard !currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let userMessage = currentInput
        currentInput = ""

        // Add user message
        messages.append(Message(type: .user, content: userMessage))

        // For MVP: Parse the user's message into requirements
        // In Phase 3B, this will be handled by local LLM
        Task {
            await generateCodeFromMessage(userMessage)
        }
    }

    private func generateCodeFromMessage(_ userMessage: String) async {
        isGenerating = true

        // Add "thinking" message
        let thinkingMessage = Message(type: .assistant, content: "Generating code...")
        messages.append(thinkingMessage)

        do {
            // For demo: create simple requirements from user message
            // In reality, this would come from conversation with local LLM
            let requirements = createDemoRequirements(from: userMessage)

            let response = try await serverClient.generateCode(requirements: requirements)

            // Remove thinking message
            if let index = messages.firstIndex(where: { $0.id == thinkingMessage.id }) {
                messages.remove(at: index)
            }

            // Add code result message
            messages.append(Message(
                type: .code,
                content: "Code generated successfully!",
                codeResult: response.code
            ))

        } catch {
            // Remove thinking message
            if let index = messages.firstIndex(where: { $0.id == thinkingMessage.id }) {
                messages.remove(at: index)
            }

            // Show error
            messages.append(Message(
                type: .error,
                content: "Error: \(error.localizedDescription)"
            ))
        }

        isGenerating = false
    }

    // MARK: - Demo Helper (Remove in Phase 3B)

    private func createDemoRequirements(from message: String) -> FunctionRequirements {
        // This is a simplified demo - just creates a prime checker
        // In Phase 3B, the local LLM will generate proper requirements
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
