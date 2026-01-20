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
    case flowchart
    case code
    case error
}

struct Message: Identifiable {
    let id = UUID()
    let type: MessageType
    let content: String
    let timestamp: Date
    var flowchart: Flowchart?
    var codeResult: CodeResult?

    init(type: MessageType, content: String, flowchart: Flowchart? = nil, codeResult: CodeResult? = nil) {
        self.type = type
        self.content = content
        self.flowchart = flowchart
        self.codeResult = codeResult
        self.timestamp = Date()
    }
}
