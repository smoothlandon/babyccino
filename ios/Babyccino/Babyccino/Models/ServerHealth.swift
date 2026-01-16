//
//  ServerHealth.swift
//  Babyccino
//
//  Server health check response model
//

import Foundation

struct ServerHealth: Codable {
    let status: String
    let version: String
    let llmProvider: String
    let model: String
    let modelAvailable: Bool

    enum CodingKeys: String, CodingKey {
        case status, version
        case llmProvider = "llm_provider"
        case model
        case modelAvailable = "model_available"
    }

    var isHealthy: Bool {
        status == "ok" && modelAvailable
    }
}
