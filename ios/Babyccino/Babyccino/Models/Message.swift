//
//  Message.swift
//  Babyccino
//
//  Chat message model
//

import Foundation

enum MessageType {
    case user
    case assistant
    case code
    case error
}

struct Message: Identifiable {
    let id = UUID()
    let type: MessageType
    let content: String
    let timestamp: Date
    var codeResult: CodeResult?

    init(type: MessageType, content: String, codeResult: CodeResult? = nil) {
        self.type = type
        self.content = content
        self.codeResult = codeResult
        self.timestamp = Date()
    }
}
