//
//  FlowchartGenerator.swift
//  Babyccino
//
//  Simple local flowchart generator for basic function flows
//

import Foundation

class FlowchartGenerator {

    /// Generate a simple flowchart from function requirements
    /// Uses a deterministic algorithm to create a standard flow:
    /// Start → Input → Edge cases → Process → Return
    func generateSimpleFlowchart(from requirements: FunctionRequirements) -> Flowchart {
        var nodes: [FlowchartNode] = []
        var edges: [FlowchartEdge] = []
        var currentY: Double = 50
        let centerX: Double = 200
        let verticalSpacing: Double = 120

        var nodeCounter = 0

        func nextNodeId() -> String {
            nodeCounter += 1
            return "node_\(nodeCounter)"
        }

        // 1. Start node
        let startId = nextNodeId()
        nodes.append(FlowchartNode(
            id: startId,
            type: .start,
            label: "Start",
            x: centerX,
            y: currentY
        ))
        currentY += verticalSpacing

        // 2. Input node (if there are parameters)
        var lastNodeId = startId
        if !requirements.parameters.isEmpty {
            let inputId = nextNodeId()
            let paramList = requirements.parameters.map { $0.name }.joined(separator: ", ")
            nodes.append(FlowchartNode(
                id: inputId,
                type: .input,
                label: "Input: \(paramList)",
                x: centerX,
                y: currentY
            ))
            edges.append(FlowchartEdge(id: "e_\(edges.count + 1)", from: lastNodeId, to: inputId))
            lastNodeId = inputId
            currentY += verticalSpacing
        }

        // 3. Edge case checks (if any)
        for (index, edgeCase) in requirements.edgeCases.prefix(2).enumerated() {
            let decisionId = nextNodeId()

            // Simplify edge case text for display
            let simplifiedCase = simplifyEdgeCase(edgeCase)
            nodes.append(FlowchartNode(
                id: decisionId,
                type: .decision,
                label: simplifiedCase,
                x: centerX,
                y: currentY
            ))
            edges.append(FlowchartEdge(id: "e_\(edges.count + 1)", from: lastNodeId, to: decisionId))

            // Return path for edge case
            let returnId = nextNodeId()
            let returnValue = extractReturnValue(from: edgeCase)
            nodes.append(FlowchartNode(
                id: returnId,
                type: .end,
                label: "Return \(returnValue)",
                x: centerX - 150,
                y: currentY + 100
            ))
            edges.append(FlowchartEdge(id: "e_\(edges.count + 1)", from: decisionId, to: returnId, label: "Yes"))

            lastNodeId = decisionId
            currentY += verticalSpacing
        }

        // 4. Main process node
        let processId = nextNodeId()
        nodes.append(FlowchartNode(
            id: processId,
            type: .function,
            label: requirements.name + "()",
            x: centerX,
            y: currentY,
            functionName: requirements.name,
            description: requirements.purpose
        ))

        // Connect from last edge case or input
        if requirements.edgeCases.count > 0 {
            edges.append(FlowchartEdge(id: "e_\(edges.count + 1)", from: lastNodeId, to: processId, label: "No"))
        } else {
            edges.append(FlowchartEdge(id: "e_\(edges.count + 1)", from: lastNodeId, to: processId))
        }

        lastNodeId = processId
        currentY += verticalSpacing

        // 5. Return node
        let returnId = nextNodeId()
        nodes.append(FlowchartNode(
            id: returnId,
            type: .output,
            label: "Return \(requirements.returnType)",
            x: centerX,
            y: currentY
        ))
        edges.append(FlowchartEdge(id: "e_\(edges.count + 1)", from: lastNodeId, to: returnId))
        lastNodeId = returnId
        currentY += verticalSpacing

        // 6. End node
        let endId = nextNodeId()
        nodes.append(FlowchartNode(
            id: endId,
            type: .end,
            label: "End",
            x: centerX,
            y: currentY
        ))
        edges.append(FlowchartEdge(id: "e_\(edges.count + 1)", from: lastNodeId, to: endId))

        return Flowchart(
            nodes: nodes,
            edges: edges,
            title: "\(requirements.name)() - \(requirements.purpose)",
            description: "Simple flowchart showing the basic logic flow"
        )
    }

    // MARK: - Helper Functions

    /// Simplify edge case text for decision node display
    private func simplifyEdgeCase(_ edgeCase: String) -> String {
        // Extract the condition part before "returns" or "return"
        let lowercased = edgeCase.lowercased()

        if let range = lowercased.range(of: "return") {
            let condition = String(edgeCase[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            return condition.isEmpty ? "Edge case?" : condition + "?"
        }

        // If no "return" found, use the whole thing but limit length
        let trimmed = edgeCase.trimmingCharacters(in: .whitespaces)
        if trimmed.count > 30 {
            return String(trimmed.prefix(27)) + "...?"
        }
        return trimmed + "?"
    }

    /// Extract return value from edge case description
    private func extractReturnValue(from edgeCase: String) -> String {
        let lowercased = edgeCase.lowercased()

        // Look for "returns X" or "return X"
        if let range = lowercased.range(of: "return") {
            let afterReturn = String(edgeCase[range.upperBound...]).trimmingCharacters(in: .whitespaces)

            // Take first word/value
            let components = afterReturn.split(separator: " ")
            if let first = components.first {
                return String(first).trimmingCharacters(in: CharacterSet.punctuationCharacters)
            }
        }

        return "value"
    }
}
