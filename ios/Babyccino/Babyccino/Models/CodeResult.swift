//
//  CodeResult.swift
//  Babyccino
//
//  Data models for code generation results from server
//

import Foundation

struct TestCaseResult: Codable, Identifiable {
    let id = UUID()
    let name: String
    let passed: Bool
    let output: String

    enum CodingKeys: String, CodingKey {
        case name, passed, output
    }
}

struct TestResult: Codable {
    let code: String
    let results: [TestCaseResult]
    let summary: String
}

struct ComplexityResult: Codable {
    let time: String
    let space: String
    let explanation: String
}

struct CodeResult: Codable, Identifiable {
    let id = UUID()
    let functionName: String
    let function: String
    let tests: TestResult
    let complexity: ComplexityResult

    enum CodingKeys: String, CodingKey {
        case functionName = "function_name"
        case function, tests, complexity
    }
}

struct GenerateCodeResponse: Codable {
    let conversationId: String
    let results: [CodeResult]

    enum CodingKeys: String, CodingKey {
        case conversationId = "conversation_id"
        case results
    }

    // Legacy compatibility: expose first result as 'code' for single-function calls
    var code: CodeResult {
        results[0]
    }
}
