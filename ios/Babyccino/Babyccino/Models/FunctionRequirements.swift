//
//  FunctionRequirements.swift
//  Babyccino
//
//  Data model for function requirements sent to server
//

import Foundation

struct FunctionParameter: Codable, Identifiable {
    let id = UUID()
    let name: String
    let type: String
    let description: String

    enum CodingKeys: String, CodingKey {
        case name, type, description
    }
}

struct FunctionExample: Codable, Identifiable {
    let id = UUID()
    let input: String
    let output: String

    enum CodingKeys: String, CodingKey {
        case input, output
    }
}

struct FunctionRequirements: Codable {
    let name: String
    let purpose: String
    let parameters: [FunctionParameter]
    let returnType: String
    let edgeCases: [String]
    let examples: [FunctionExample]

    enum CodingKeys: String, CodingKey {
        case name, purpose, parameters
        case returnType = "return_type"
        case edgeCases = "edge_cases"
        case examples
    }
}
