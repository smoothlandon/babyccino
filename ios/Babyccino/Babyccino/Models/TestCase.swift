//
//  TestCase.swift
//  Babyccino
//
//  Models for test case generation and user approval flow
//

import Foundation

/// A proposed test case returned by the server for user review
struct ProposedTestCase: Codable, Identifiable {
    let id: String
    let description: String
    let input: String
    let expectedOutput: String
    let isEdgeCase: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case description
        case input
        case expectedOutput = "expected_output"
        case isEdgeCase = "is_edge_case"
    }
}

/// Server response from POST /generate-tests
struct GenerateTestsResponse: Codable {
    let functionName: String
    let proposedTests: [ProposedTestCase]

    enum CodingKeys: String, CodingKey {
        case functionName = "function_name"
        case proposedTests = "proposed_tests"
    }
}

/// A user-approved test case — sent back to server with generate-code request
struct ApprovedTestCase: Codable, Identifiable {
    let id: String
    let description: String
    let input: String
    let expectedOutput: String
    let isEdgeCase: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case description
        case input
        case expectedOutput = "expected_output"
        case isEdgeCase = "is_edge_case"
    }

    /// Convert a proposed test case to an approved one
    init(from proposed: ProposedTestCase) {
        self.id = proposed.id
        self.description = proposed.description
        self.input = proposed.input
        self.expectedOutput = proposed.expectedOutput
        self.isEdgeCase = proposed.isEdgeCase
    }

    init(id: String, description: String, input: String, expectedOutput: String, isEdgeCase: Bool) {
        self.id = id
        self.description = description
        self.input = input
        self.expectedOutput = expectedOutput
        self.isEdgeCase = isEdgeCase
    }
}
