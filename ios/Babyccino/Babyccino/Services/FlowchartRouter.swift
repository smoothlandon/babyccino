//
//  FlowchartRouter.swift
//  Babyccino
//
//  Routes flowchart generation to local or server based on complexity
//

import Foundation

class FlowchartRouter {
    private let llmService: LLMService
    private let localGenerator: FlowchartGenerator
    private let serverURL: String

    init(llmService: LLMService, serverURL: String) {
        self.llmService = llmService
        self.localGenerator = FlowchartGenerator()
        self.serverURL = serverURL
    }

    /// Generate flowchart by routing to local or server based on complexity
    func generateFlowchart(requirements: FunctionRequirements) async throws -> Flowchart {
        // 1. Classify complexity using on-device LLM
        let complexity = try await llmService.classifyFlowchartComplexity(requirements: requirements)

        // 2. Route based on classification
        switch complexity {
        case .simple:
            // Generate locally using deterministic algorithm
            return localGenerator.generateSimpleFlowchart(from: requirements)

        case .complex:
            // Request from server
            return try await requestFlowchartFromServer(requirements: requirements)
        }
    }

    // MARK: - Server Communication

    private func requestFlowchartFromServer(requirements: FunctionRequirements) async throws -> Flowchart {
        guard let url = URL(string: "\(serverURL)/api/generate-flowchart") else {
            throw FlowchartError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Create request body
        let requestBody = FlowchartRequest(requirements: requirements)
        request.httpBody = try JSONEncoder().encodeWithSnakeCase(requestBody)

        // Send request
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FlowchartError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw FlowchartError.serverError(statusCode: httpResponse.statusCode)
        }

        // Decode response
        let flowchartResponse = try JSONDecoder().decodeWithSnakeCase(FlowchartResponse.self, from: data)
        return flowchartResponse.flowchart
    }
}

// MARK: - Request/Response Models

struct FlowchartRequest: Codable {
    let requirements: FunctionRequirements
}

struct FlowchartResponse: Codable {
    let flowchart: Flowchart
}

// MARK: - Errors

enum FlowchartError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let code):
            return "Server error: \(code)"
        }
    }
}

// MARK: - JSON Encoding Helpers

extension JSONEncoder {
    func encodeWithSnakeCase<T: Encodable>(_ value: T) throws -> Data {
        self.keyEncodingStrategy = .convertToSnakeCase
        return try self.encode(value)
    }
}

extension JSONDecoder {
    func decodeWithSnakeCase<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        self.keyDecodingStrategy = .convertFromSnakeCase
        return try self.decode(type, from: data)
    }
}
