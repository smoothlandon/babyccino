//
//  LLMServiceFactory.swift
//  Babyccino
//
//  Factory for creating appropriate LLM service based on environment
//

import Foundation

class LLMServiceFactory {
    static func createLLMService() -> LLMService {
        #if targetEnvironment(simulator)
        // Use mock LLM in iOS simulator (MLX doesn't work without Metal)
        return MockLLMService()
        #else
        // Use real MLX LLM on physical device or Mac (Designed for iPad)
        // Both have Metal support
        // Default to Qwen 1.5B - best balance of speed and JSON reliability
        return MLXLLMService(config: .qwen15b)
        #endif
    }
}
