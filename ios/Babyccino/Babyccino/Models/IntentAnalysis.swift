//
//  IntentAnalysis.swift
//  Babyccino
//
//  Intent analysis structure returned by LLM
//

import Foundation

/// LLM's analysis of user intent (structured JSON output)
struct IntentAnalysis: Codable {
    let functionName: String
    let functionType: FunctionType
    let specStatus: SpecStatus
    let questions: [String]
    let purpose: String?

    /// Whether the model recognized a function request at all
    enum FunctionType: String, Codable {
        case wellKnown = "well_known"   // palindrome, prime, fibonacci, etc.
        case custom = "custom"          // user-defined logic
        case unclear = "unclear"        // no function described yet
    }

    /// Whether the spec is complete enough to generate code
    enum SpecStatus: String, Codable {
        case complete = "complete"          // ready to generate
        case needsRules = "needs_rules"     // logic is subjective/undefined - must ask
        case needsDetails = "needs_details" // inputs/outputs unclear - ask 1-2 questions
    }

    enum CodingKeys: String, CodingKey {
        case functionName = "function_name"
        case functionType = "function_type"
        case specStatus = "spec_status"
        case questions
        case purpose
    }
}

/// Template-based responses for different scenarios
enum ResponseTemplate {
    case readyToGenerate(purpose: String?)
    case needsRules(questions: [String])
    case needsDetails(questions: [String])
    case needsFunctionDescription
    case awaitingCommand

    var text: String {
        switch self {
        case .readyToGenerate(let purpose):
            if let purpose = purpose, !purpose.isEmpty {
                return "Got it - \(purpose.lowercased()). Does that sound right? Say 'generate code' if yes, or clarify if needed."
            } else {
                return "I can help with that. Say 'generate code' when ready, or clarify if needed."
            }

        case .needsRules(let questions):
            // Logic is subjective - need rules before we can generate
            let numbered = questions.enumerated().map { "\($0 + 1). \($1)" }.joined(separator: "\n")
            if questions.count == 1 {
                return questions[0]
            }
            return "I need to understand the logic before generating this. A few questions:\n\n\(numbered)"

        case .needsDetails(let questions):
            // Just missing some input/output details
            if questions.count == 1 {
                return questions[0]
            }
            let numbered = questions.enumerated().map { "\($0 + 1). \($1)" }.joined(separator: "\n")
            return "A few questions:\n\n\(numbered)"

        case .needsFunctionDescription:
            return "Sure! What kind of function would you like to create?"

        case .awaitingCommand:
            return "Say 'generate code' to create the function."
        }
    }
}
