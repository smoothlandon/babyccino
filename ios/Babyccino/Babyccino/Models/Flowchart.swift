//
//  Flowchart.swift
//  Babyccino
//
//  Data models for flowchart visualization
//

import Foundation

// MARK: - Node Types

enum FlowchartNodeType: String, Codable {
    case start      // Start/Entry point (rounded rectangle, green)
    case end        // End/Exit point (rounded rectangle, red)
    case process    // Process/Action (rectangle, blue)
    case decision   // Decision/Conditional (diamond, yellow)
    case input      // Input (parallelogram, purple)
    case output     // Output (parallelogram, purple)
    case function   // Function call (rectangle with double borders, blue)
}

// MARK: - Flowchart Node

struct FlowchartNode: Codable, Identifiable {
    let id: String
    let type: FlowchartNodeType
    let label: String
    let x: Double
    let y: Double

    // Optional metadata
    let functionName: String?  // For function nodes, links to generated code
    let description: String?   // Additional details

    init(id: String, type: FlowchartNodeType, label: String, x: Double, y: Double,
         functionName: String? = nil, description: String? = nil) {
        self.id = id
        self.type = type
        self.label = label
        self.x = x
        self.y = y
        self.functionName = functionName
        self.description = description
    }
}

// MARK: - Flowchart Edge

struct FlowchartEdge: Codable, Identifiable {
    let id: String
    let from: String  // Node ID
    let to: String    // Node ID
    let label: String?  // Optional label for decision branches (e.g., "Yes", "No", "Valid")

    init(id: String, from: String, to: String, label: String? = nil) {
        self.id = id
        self.from = from
        self.to = to
        self.label = label
    }
}

// MARK: - Flowchart

struct Flowchart: Codable {
    let nodes: [FlowchartNode]
    let edges: [FlowchartEdge]
    let title: String?
    let description: String?

    init(nodes: [FlowchartNode], edges: [FlowchartEdge],
         title: String? = nil, description: String? = nil) {
        self.nodes = nodes
        self.edges = edges
        self.title = title
        self.description = description
    }
}
