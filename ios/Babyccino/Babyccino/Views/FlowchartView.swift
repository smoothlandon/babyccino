//
//  FlowchartView.swift
//  Babyccino
//
//  Interactive flowchart visualization
//

import SwiftUI

struct FlowchartView: View {
    let flowchart: Flowchart

    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color(white: 0.98)

                // Flowchart content
                Canvas { context, size in
                    // Calculate bounds to center the flowchart
                    let bounds = calculateBounds()
                    let centerX = size.width / 2
                    let centerY = size.height / 2
                    let flowchartCenterX = (bounds.minX + bounds.maxX) / 2
                    let flowchartCenterY = (bounds.minY + bounds.maxY) / 2

                    // Apply transformations
                    context.translateBy(
                        x: centerX - flowchartCenterX * scale + offset.width,
                        y: centerY - flowchartCenterY * scale + offset.height
                    )
                    context.scaleBy(x: scale, y: scale)

                    // Draw edges first (so they appear behind nodes)
                    for edge in flowchart.edges {
                        drawEdge(context: context, edge: edge)
                    }

                    // Draw nodes
                    for node in flowchart.nodes {
                        drawNode(context: context, node: node)
                    }
                }
                .gesture(
                    SimultaneousGesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = max(0.5, min(value, 3.0))
                            },
                        DragGesture()
                            .onChanged { value in
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            }
                    )
                )

                // Title overlay (if present)
                if let title = flowchart.title {
                    VStack {
                        HStack {
                            Text(title)
                                .font(.headline)
                                .padding(8)
                                .background(Color.white.opacity(0.9))
                                .cornerRadius(8)
                            Spacer()
                        }
                        .padding()
                        Spacer()
                    }
                }

                // Reset button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: resetView) {
                            Image(systemName: "arrow.counterclockwise")
                                .padding(10)
                                .background(Color.white.opacity(0.9))
                                .clipShape(Circle())
                        }
                        .padding()
                    }
                }
            }
        }
    }

    // MARK: - Drawing Functions

    private func drawNode(context: GraphicsContext, node: FlowchartNode) {
        let center = CGPoint(x: node.x, y: node.y)
        let size = nodeSize(for: node)

        var path: Path
        let color = nodeColor(for: node.type)

        switch node.type {
        case .start, .end:
            // Rounded rectangle
            path = Path(roundedRect: CGRect(
                x: center.x - size.width / 2,
                y: center.y - size.height / 2,
                width: size.width,
                height: size.height
            ), cornerRadius: 20)

        case .decision:
            // Diamond shape
            path = Path()
            path.move(to: CGPoint(x: center.x, y: center.y - size.height / 2))
            path.addLine(to: CGPoint(x: center.x + size.width / 2, y: center.y))
            path.addLine(to: CGPoint(x: center.x, y: center.y + size.height / 2))
            path.addLine(to: CGPoint(x: center.x - size.width / 2, y: center.y))
            path.closeSubpath()

        case .input, .output:
            // Parallelogram
            let skew: CGFloat = 15
            path = Path()
            path.move(to: CGPoint(x: center.x - size.width / 2 + skew, y: center.y - size.height / 2))
            path.addLine(to: CGPoint(x: center.x + size.width / 2 + skew, y: center.y - size.height / 2))
            path.addLine(to: CGPoint(x: center.x + size.width / 2 - skew, y: center.y + size.height / 2))
            path.addLine(to: CGPoint(x: center.x - size.width / 2 - skew, y: center.y + size.height / 2))
            path.closeSubpath()

        case .function:
            // Rectangle with double border
            path = Path(roundedRect: CGRect(
                x: center.x - size.width / 2,
                y: center.y - size.height / 2,
                width: size.width,
                height: size.height
            ), cornerRadius: 5)

        case .process:
            // Simple rectangle
            path = Path(roundedRect: CGRect(
                x: center.x - size.width / 2,
                y: center.y - size.height / 2,
                width: size.width,
                height: size.height
            ), cornerRadius: 5)
        }

        // Fill shape
        context.fill(path, with: .color(color.opacity(0.3)))

        // Stroke outline
        context.stroke(path, with: .color(color), lineWidth: 2)

        // Draw double border for function nodes
        if node.type == .function {
            let innerPath = Path(roundedRect: CGRect(
                x: center.x - size.width / 2 + 5,
                y: center.y - size.height / 2 + 5,
                width: size.width - 10,
                height: size.height - 10
            ), cornerRadius: 5)
            context.stroke(innerPath, with: .color(color), lineWidth: 2)
        }

        // Draw label
        context.draw(Text(node.label)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.black),
            at: center,
            anchor: .center
        )
    }

    private func drawEdge(context: GraphicsContext, edge: FlowchartEdge) {
        guard let fromNode = flowchart.nodes.first(where: { $0.id == edge.from }),
              let toNode = flowchart.nodes.first(where: { $0.id == edge.to }) else {
            return
        }

        let fromPoint = CGPoint(x: fromNode.x, y: fromNode.y)
        let toPoint = CGPoint(x: toNode.x, y: toNode.y)

        // Calculate edge connection points (on node boundaries)
        let fromSize = nodeSize(for: fromNode)
        let toSize = nodeSize(for: toNode)

        let angle = atan2(toPoint.y - fromPoint.y, toPoint.x - fromPoint.x)

        let fromEdge = CGPoint(
            x: fromPoint.x + cos(angle) * fromSize.width / 2,
            y: fromPoint.y + sin(angle) * fromSize.height / 2
        )

        let toEdge = CGPoint(
            x: toPoint.x - cos(angle) * toSize.width / 2,
            y: toPoint.y - sin(angle) * toSize.height / 2
        )

        // Draw line
        var path = Path()
        path.move(to: fromEdge)
        path.addLine(to: toEdge)

        context.stroke(path, with: .color(.gray), lineWidth: 2)

        // Draw arrowhead
        let arrowSize: CGFloat = 10
        let arrowAngle: CGFloat = .pi / 6

        var arrowPath = Path()
        arrowPath.move(to: toEdge)
        arrowPath.addLine(to: CGPoint(
            x: toEdge.x - arrowSize * cos(angle - arrowAngle),
            y: toEdge.y - arrowSize * sin(angle - arrowAngle)
        ))
        arrowPath.move(to: toEdge)
        arrowPath.addLine(to: CGPoint(
            x: toEdge.x - arrowSize * cos(angle + arrowAngle),
            y: toEdge.y - arrowSize * sin(angle + arrowAngle)
        ))

        context.stroke(arrowPath, with: .color(.gray), lineWidth: 2)

        // Draw edge label (if present)
        if let label = edge.label, !label.isEmpty {
            let midPoint = CGPoint(
                x: (fromEdge.x + toEdge.x) / 2,
                y: (fromEdge.y + toEdge.y) / 2
            )

            // Draw white background for label
            let labelSize = CGSize(width: CGFloat(label.count) * 8, height: 20)
            let bgRect = CGRect(
                x: midPoint.x - labelSize.width / 2,
                y: midPoint.y - labelSize.height / 2,
                width: labelSize.width,
                height: labelSize.height
            )
            context.fill(Path(roundedRect: bgRect, cornerRadius: 4), with: .color(.white.opacity(0.9)))

            // Draw label text
            context.draw(Text(label)
                .font(.system(size: 12))
                .foregroundColor(.gray),
                at: midPoint,
                anchor: .center
            )
        }
    }

    // MARK: - Helper Functions

    private func nodeColor(for type: FlowchartNodeType) -> Color {
        switch type {
        case .start:
            return .green
        case .end:
            return .red
        case .process, .function:
            return .blue
        case .decision:
            return .yellow
        case .input, .output:
            return .purple
        }
    }

    private func nodeSize(for node: FlowchartNode) -> CGSize {
        // Estimate size based on label length
        let baseWidth: CGFloat = 120
        let baseHeight: CGFloat = 60

        let labelLength = CGFloat(node.label.count)
        let width = max(baseWidth, labelLength * 8)

        switch node.type {
        case .decision:
            return CGSize(width: width * 1.2, height: baseHeight * 1.2)
        default:
            return CGSize(width: width, height: baseHeight)
        }
    }

    private func calculateBounds() -> (minX: CGFloat, maxX: CGFloat, minY: CGFloat, maxY: CGFloat) {
        guard !flowchart.nodes.isEmpty else {
            return (0, 0, 0, 0)
        }

        let xs = flowchart.nodes.map { $0.x }
        let ys = flowchart.nodes.map { $0.y }

        return (
            minX: xs.min() ?? 0,
            maxX: xs.max() ?? 0,
            minY: ys.min() ?? 0,
            maxY: ys.max() ?? 0
        )
    }

    private func resetView() {
        withAnimation {
            scale = 1.0
            offset = .zero
            lastOffset = .zero
        }
    }
}

// MARK: - Preview

#Preview {
    FlowchartView(flowchart: Flowchart(
        nodes: [
            FlowchartNode(id: "1", type: .start, label: "Start", x: 200, y: 50),
            FlowchartNode(id: "2", type: .process, label: "validate_credentials()", x: 200, y: 150, functionName: "validate_credentials"),
            FlowchartNode(id: "3", type: .decision, label: "Valid?", x: 200, y: 270),
            FlowchartNode(id: "4", type: .process, label: "create_session()", x: 350, y: 390, functionName: "create_session"),
            FlowchartNode(id: "5", type: .end, label: "Return Success", x: 350, y: 490),
            FlowchartNode(id: "6", type: .end, label: "Return Error", x: 50, y: 390)
        ],
        edges: [
            FlowchartEdge(id: "e1", from: "1", to: "2"),
            FlowchartEdge(id: "e2", from: "2", to: "3"),
            FlowchartEdge(id: "e3", from: "3", to: "4", label: "Yes"),
            FlowchartEdge(id: "e4", from: "3", to: "6", label: "No"),
            FlowchartEdge(id: "e5", from: "4", to: "5")
        ],
        title: "Authentication Flow"
    ))
}
