//
//  TestApprovalView.swift
//  Babyccino
//
//  Lets the user review, edit, and approve proposed test cases before code generation
//

import SwiftUI

struct TestApprovalView: View {
    let functionName: String
    let proposedTests: [ProposedTestCase]
    let onApprove: ([ApprovedTestCase]) -> Void
    let onCancel: () -> Void

    // Local editable state for each test case
    @State private var testStates: [TestRowState]
    @State private var showingAddTest = false
    @State private var newDescription = ""
    @State private var newInput = ""
    @State private var newExpected = ""
    @State private var newIsEdgeCase = false

    init(
        functionName: String,
        proposedTests: [ProposedTestCase],
        onApprove: @escaping ([ApprovedTestCase]) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.functionName = functionName
        self.proposedTests = proposedTests
        self.onApprove = onApprove
        self.onCancel = onCancel
        _testStates = State(initialValue: proposedTests.map { TestRowState(from: $0) })
    }

    var approvedCount: Int {
        testStates.filter { $0.isIncluded }.count
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header explanation
                VStack(alignment: .leading, spacing: 6) {
                    Text("Review test cases for \(functionName)()")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("These define the contract. Remove or edit any that don't match your intent, then approve.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(Color(.systemGroupedBackground))

                List {
                    // Normal cases
                    let normalTests = testStates.indices.filter { !testStates[$0].isEdgeCase }
                    if !normalTests.isEmpty {
                        Section("Normal Cases") {
                            ForEach(normalTests, id: \.self) { idx in
                                TestRowView(state: $testStates[idx])
                            }
                            .onDelete { offsets in
                                deleteTests(at: offsets, from: normalTests)
                            }
                        }
                    }

                    // Edge cases
                    let edgeCaseTests = testStates.indices.filter { testStates[$0].isEdgeCase }
                    if !edgeCaseTests.isEmpty {
                        Section("Edge Cases") {
                            ForEach(edgeCaseTests, id: \.self) { idx in
                                TestRowView(state: $testStates[idx])
                            }
                            .onDelete { offsets in
                                deleteTests(at: offsets, from: edgeCaseTests)
                            }
                        }
                    }

                    // Add test button
                    Section {
                        Button(action: { showingAddTest = true }) {
                            Label("Add test case", systemImage: "plus.circle")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                .listStyle(.insetGrouped)

                // Bottom bar
                VStack(spacing: 0) {
                    Divider()
                    HStack(spacing: 16) {
                        Button("Cancel", action: onCancel)
                            .foregroundColor(.secondary)

                        Spacer()

                        Text("\(approvedCount) test\(approvedCount == 1 ? "" : "s") selected")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Button(action: approve) {
                            Text("Generate Code")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(approvedCount > 0 ? Color.accentColor : Color.gray)
                                .cornerRadius(10)
                        }
                        .disabled(approvedCount == 0)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(Color(.systemBackground))
                }
            }
            .navigationTitle("Test Cases")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingAddTest) {
                addTestSheet
            }
        }
    }

    private func approve() {
        let approved = testStates
            .filter { $0.isIncluded }
            .map { $0.toApprovedTestCase() }
        onApprove(approved)
    }

    private func deleteTests(at offsets: IndexSet, from indices: [Int]) {
        let toDelete = offsets.map { indices[$0] }
        for idx in toDelete.sorted(by: >) {
            testStates.remove(at: idx)
        }
    }

    private var addTestSheet: some View {
        NavigationView {
            Form {
                Section("Description") {
                    TextField("e.g. fun name with many vowels", text: $newDescription)
                }
                Section("Input") {
                    TextField("e.g. \"Alexandria\"", text: $newInput)
                        .font(.system(.body, design: .monospaced))
                }
                Section("Expected Output") {
                    TextField("e.g. True", text: $newExpected)
                        .font(.system(.body, design: .monospaced))
                }
                Section {
                    Toggle("Edge case", isOn: $newIsEdgeCase)
                }
            }
            .navigationTitle("Add Test Case")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingAddTest = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let new = TestRowState(
                            id: UUID().uuidString,
                            description: newDescription,
                            input: newInput,
                            expectedOutput: newExpected,
                            isEdgeCase: newIsEdgeCase,
                            isIncluded: true
                        )
                        testStates.append(new)
                        newDescription = ""
                        newInput = ""
                        newExpected = ""
                        newIsEdgeCase = false
                        showingAddTest = false
                    }
                    .disabled(newDescription.isEmpty || newInput.isEmpty || newExpected.isEmpty)
                }
            }
        }
    }
}

// MARK: - Test row editable state

struct TestRowState {
    let id: String
    var description: String
    var input: String
    var expectedOutput: String
    var isEdgeCase: Bool
    var isIncluded: Bool

    init(from proposed: ProposedTestCase) {
        self.id = proposed.id
        self.description = proposed.description
        self.input = proposed.input
        self.expectedOutput = proposed.expectedOutput
        self.isEdgeCase = proposed.isEdgeCase
        self.isIncluded = true
    }

    init(id: String, description: String, input: String, expectedOutput: String,
         isEdgeCase: Bool, isIncluded: Bool) {
        self.id = id
        self.description = description
        self.input = input
        self.expectedOutput = expectedOutput
        self.isEdgeCase = isEdgeCase
        self.isIncluded = isIncluded
    }

    func toApprovedTestCase() -> ApprovedTestCase {
        ApprovedTestCase(
            id: id,
            description: description,
            input: input,
            expectedOutput: expectedOutput,
            isEdgeCase: isEdgeCase
        )
    }
}

// MARK: - Individual test row

struct TestRowView: View {
    @Binding var state: TestRowState
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Collapsed header row
            HStack(spacing: 12) {
                Image(systemName: state.isIncluded ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(state.isIncluded ? .accentColor : .secondary)
                    .font(.title3)
                    .onTapGesture { state.isIncluded.toggle() }

                VStack(alignment: .leading, spacing: 2) {
                    Text(state.description)
                        .font(.subheadline)
                        .foregroundColor(state.isIncluded ? .primary : .secondary)
                        .strikethrough(!state.isIncluded)

                    HStack(spacing: 4) {
                        Text(state.input)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                        Text("→")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(state.expectedOutput)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(state.isIncluded ? .accentColor : .secondary)
                    }
                }

                Spacer()

                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .padding(.vertical, 6)

            // Expanded edit fields
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    LabeledContent("Description") {
                        TextField("Description", text: $state.description)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Input") {
                        TextField("Input", text: $state.input)
                            .multilineTextAlignment(.trailing)
                            .font(.system(.body, design: .monospaced))
                    }
                    LabeledContent("Expected") {
                        TextField("Expected output", text: $state.expectedOutput)
                            .multilineTextAlignment(.trailing)
                            .font(.system(.body, design: .monospaced))
                    }
                }
                .padding(.bottom, 6)
            }
        }
    }
}
