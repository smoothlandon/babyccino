//
//  ServerClient.swift
//  Babyccino
//
//  HTTP client for communicating with the FastAPI server
//

import Foundation
import Combine

enum ServerError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case serverError(String)
    case notConnected

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .serverError(let message):
            return "Server error: \(message)"
        case .notConnected:
            return "Not connected to server"
        }
    }
}

class ServerClient: ObservableObject {
    @Published var serverURL: String {
        didSet {
            UserDefaults.standard.set(serverURL, forKey: "serverURL")
        }
    }

    @Published var isConnected = false
    @Published var serverHealth: ServerHealth?

    init() {
        // Load saved server URL or use default
        self.serverURL = UserDefaults.standard.string(forKey: "serverURL") ?? "http://192.168.1.100:8000"
    }

    // MARK: - Health Check

    @MainActor
    func checkHealth() async throws -> ServerHealth {
        guard let url = URL(string: "\(serverURL)/health") else {
            throw ServerError.invalidURL
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let health = try JSONDecoder().decode(ServerHealth.self, from: data)

            self.serverHealth = health
            self.isConnected = health.isHealthy

            return health
        } catch let error as DecodingError {
            self.isConnected = false
            throw ServerError.decodingError(error)
        } catch {
            self.isConnected = false
            throw ServerError.networkError(error)
        }
    }

    // MARK: - Generate Tests (propose for user approval)

    @MainActor
    func generateTests(requirements: FunctionRequirements) async throws -> GenerateTestsResponse {
        guard let url = URL(string: "\(serverURL)/generate-tests") else {
            throw ServerError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let reqJson = try encoder.encode(requirements)
        let reqObj = try JSONSerialization.jsonObject(with: reqJson) as! [String: Any]

        let requestBody: [String: Any] = ["requirements": reqObj]
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                guard (200...299).contains(httpResponse.statusCode) else {
                    if let errorMessage = String(data: data, encoding: .utf8) {
                        throw ServerError.serverError(errorMessage)
                    }
                    throw ServerError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }

            // GenerateTestsResponse uses explicit CodingKeys with snake_case strings —
            // do NOT use convertFromSnakeCase as it would double-convert the key names
            return try JSONDecoder().decode(GenerateTestsResponse.self, from: data)

        } catch let error as ServerError {
            throw error
        } catch let error as DecodingError {
            throw ServerError.decodingError(error)
        } catch {
            throw ServerError.networkError(error)
        }
    }

    // MARK: - Generate Code

    @MainActor
    func generateCode(
        requirements: [FunctionRequirements],
        approvedTests: [ApprovedTestCase]? = nil
    ) async throws -> GenerateCodeResponse {
        guard let url = URL(string: "\(serverURL)/generate-code") else {
            throw ServerError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase

        var requestBody: [String: Any] = [
            "conversation_id": NSNull(),
            "requirements": try requirements.map { req -> [String: Any] in
                let data = try encoder.encode(req)
                return try JSONSerialization.jsonObject(with: data) as! [String: Any]
            }
        ]

        if let approvedTests = approvedTests {
            requestBody["approved_tests"] = try approvedTests.map { test -> [String: Any] in
                let data = try encoder.encode(test)
                return try JSONSerialization.jsonObject(with: data) as! [String: Any]
            }
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                guard (200...299).contains(httpResponse.statusCode) else {
                    if let errorMessage = String(data: data, encoding: .utf8) {
                        throw ServerError.serverError(errorMessage)
                    }
                    throw ServerError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }

            return try JSONDecoder().decode(GenerateCodeResponse.self, from: data)

        } catch let error as ServerError {
            throw error
        } catch let error as DecodingError {
            throw ServerError.decodingError(error)
        } catch {
            throw ServerError.networkError(error)
        }
    }
}
