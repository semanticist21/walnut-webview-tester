import SwiftUI

enum FlowLayoutAlignment {
    case leading
    case center
    case trailing
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var alignment: FlowLayoutAlignment = .leading

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let arrangement = arrangeSubviews(proposal: proposal, subviews: subviews)

        for (index, position) in arrangement.positions.enumerated() {
            let lineIndex = arrangement.lineIndices[index]
            let lineWidth = arrangement.lineWidths[lineIndex]
            let containerWidth = bounds.width

            let offsetX: CGFloat
            switch alignment {
            case .leading:
                offsetX = 0
            case .center:
                offsetX = (containerWidth - lineWidth) / 2
            case .trailing:
                offsetX = containerWidth - lineWidth
            }

            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x + offsetX, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint], lineWidths: [CGFloat], lineIndices: [Int]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var lineWidths: [CGFloat] = []
        var lineIndices: [Int] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var currentLineIndex = 0
        var currentLineWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                lineWidths.append(currentLineWidth - spacing)
                currentLineIndex += 1
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
                currentLineWidth = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineIndices.append(currentLineIndex)
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            currentLineWidth = currentX
            totalHeight = currentY + lineHeight
        }

        lineWidths.append(currentLineWidth - spacing)

        return (CGSize(width: maxWidth, height: totalHeight), positions, lineWidths, lineIndices)
    }
}
