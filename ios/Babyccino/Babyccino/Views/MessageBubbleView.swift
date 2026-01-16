//
//  MessageBubbleView.swift
//  Babyccino
//
//  Individual message bubble in chat
//

import SwiftUI

struct MessageBubbleView: View {
    let message: Message

    var body: some View {
        HStack {
            if message.type == .user {
                Spacer()
            }

            VStack(alignment: message.type == .user ? .trailing : .leading, spacing: 4) {
                if let codeResult = message.codeResult {
                    CodeResultView(codeResult: codeResult)
                } else {
                    Text(message.content)
                        .padding(12)
                        .background(bubbleColor)
                        .foregroundColor(textColor)
                        .cornerRadius(16)
                }

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }

            if message.type != .user {
                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }

    private var bubbleColor: Color {
        switch message.type {
        case .user:
            return .blue
        case .assistant:
            return Color(.systemGray5)
        case .code:
            return Color(.systemGray6)
        case .error:
            return .red.opacity(0.2)
        }
    }

    private var textColor: Color {
        message.type == .user ? .white : .primary
    }
}

struct CodeResultView: View {
    let codeResult: CodeResult
    @State private var selectedTab = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Generated Code")
                .font(.headline)

            Picker("View", selection: $selectedTab) {
                Text("Function").tag(0)
                Text("Tests").tag(1)
                Text("Complexity").tag(2)
            }
            .pickerStyle(.segmented)

            ScrollView {
                switch selectedTab {
                case 0:
                    codeView(codeResult.function)
                case 1:
                    VStack(alignment: .leading, spacing: 8) {
                        codeView(codeResult.tests.code)

                        Divider()

                        Text("Test Results: \(codeResult.tests.summary)")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        ForEach(codeResult.tests.results) { result in
                            HStack {
                                Image(systemName: result.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(result.passed ? .green : .red)
                                Text(result.name)
                                    .font(.caption)
                            }
                        }
                    }
                case 2:
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Time:")
                                .fontWeight(.medium)
                            Text(codeResult.complexity.time)
                                .font(.system(.body, design: .monospaced))
                        }

                        HStack {
                            Text("Space:")
                                .fontWeight(.medium)
                            Text(codeResult.complexity.space)
                                .font(.system(.body, design: .monospaced))
                        }

                        Divider()

                        Text(codeResult.complexity.explanation)
                            .font(.caption)
                    }
                default:
                    EmptyView()
                }
            }
            .frame(maxHeight: 400)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    private func codeView(_ code: String) -> some View {
        Text(code)
            .font(.system(.caption, design: .monospaced))
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray5))
            .cornerRadius(8)
    }
}
