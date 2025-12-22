import SwiftUI

// MARK: - Console Value View

/// ConsoleValue 객체를 트리 형태로 렌더링하는 뷰 (확장/축소 가능)
struct ConsoleValueView: View {
    let value: ConsoleValue
    @State private var isExpanded: Bool = false

    var body: some View {
        if value.isExpandable {
            expandableValueView
        } else {
            simpleValueView
        }
    }

    // MARK: - Simple Value (스칼라, 함수 등)

    private var simpleValueView: some View {
        HStack(spacing: 6) {
            Text(value.preview)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(valueTextColor)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Expandable Value (객체, 배열)

    private var expandableValueView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header (toggle + preview)
            HStack(spacing: 6) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 10)

                Text(value.preview)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(valueTextColor)
                    .textSelection(.enabled)

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isExpanded.toggle()
                }
            }

            // Children (expanded)
            if isExpanded {
                children
                    .padding(.leading, 4)
            }
        }
    }

    // MARK: - Array Chunking

    /// Split array elements into chunks of specified size
    private func makeArrayChunks(_ elements: [ConsoleValue], chunkSize: Int) -> [(startIndex: Int, endIndex: Int)] {
        guard elements.count > chunkSize else { return [(0, elements.count - 1)] }

        var chunks: [(startIndex: Int, endIndex: Int)] = []
        var index = 0
        while index < elements.count {
            let endIndex = min(index + chunkSize - 1, elements.count - 1)
            chunks.append((index, endIndex))
            index = endIndex + 1
        }
        return chunks
    }

    /// Render array as collapsible chunks
    @ViewBuilder
    private func arrayChunksView(_ allElements: [ConsoleValue], chunks: [(Int, Int)]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(chunks.enumerated()), id: \.offset) { _, chunk in
                ArrayChunkView(
                    startIndex: chunk.0,
                    endIndex: chunk.1,
                    elements: Array(allElements[chunk.0...chunk.1])
                )
            }
        }
    }

    // MARK: - Children Rendering (재귀)

    @ViewBuilder
    private var children: some View {
        switch value {
        case .object(let obj):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(obj.sortedProperties.enumerated()), id: \.element.key) { _, property in
                    let isPrototype = property.key == "[[Prototype]]"
                    let isTruncated = property.key == "[[Truncated]]"

                    if isTruncated {
                        Text("… truncated properties")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    } else {
                        HStack(alignment: .top, spacing: 6) {
                            Text(property.key)
                                .font(.system(size: 12, weight: isPrototype ? .regular : .semibold, design: .monospaced))
                                .foregroundStyle(isPrototype ? .secondary : keyColor)
                                .italic(isPrototype)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .padding(.leading, 4)

                            Text(":")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.tertiary)

                            ConsoleValueView(value: property.value)
                        }
                    }
                }
            }

        case .array(let arr):
            VStack(alignment: .leading, spacing: 4) {
                let chunks = makeArrayChunks(arr.elements, chunkSize: 100)
                if chunks.count > 1 {
                    // Large array: show chunks
                    arrayChunksView(arr.elements, chunks: chunks)
                } else {
                    // Small array: show all elements
                    ForEach(Array(arr.elements.enumerated()), id: \.offset) { index, element in
                        HStack(alignment: .top, spacing: 6) {
                            Text("[\(index)]")
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundStyle(keyColor)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .padding(.leading, 4)

                            Text(":")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.tertiary)

                            ConsoleValueView(value: element)
                        }
                    }
                }

                if arr.isTruncated, arr.totalCount > arr.elements.count {
                    Text("… \(arr.totalCount - arr.elements.count) more items")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 4)
                }
            }

        case .map(let entries):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(entries.enumerated()), id: \.element.key) { _, entry in
                    HStack(alignment: .top, spacing: 6) {
                        Text(entry.key)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(keyColor)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.leading, 4)

                        Text("→")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.tertiary)

                        ConsoleValueView(value: entry.value)
                    }
                }
            }

        case .set(let values):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(values.enumerated()), id: \.offset) { index, element in
                    HStack(alignment: .top, spacing: 6) {
                        Text("(\(index))")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(keyColor)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.leading, 4)

                        ConsoleValueView(value: element)
                    }
                }
            }

        default:
            EmptyView()
        }
    }

    // MARK: - Text Color (Eruda-like syntax highlighting)

    /// Returns color based on value type (similar to Eruda's luna-object-viewer)
    private var valueTextColor: Color {
        switch value {
        case .error: return Color(red: 1.0, green: 0.2, blue: 0.2) // Error (bright red)
        case .circularReference: return Color(red: 1.0, green: 0.7, blue: 0.0) // Circular (orange)
        case .string: return Color(red: 0.9, green: 0.6, blue: 0.0) // String color (bright orange)
        case .number: return Color(red: 0.2, green: 0.7, blue: 1.0) // Number color (bright blue)
        case .boolean: return Color(red: 0.8, green: 0.2, blue: 0.8) // Boolean color (bright magenta)
        case .null, .undefined: return Color(red: 0.7, green: 0.7, blue: 0.7) // Operator color (light gray)
        default: return .primary
        }
    }

    /// Returns key color for object properties (blue-ish, like variable names in code)
    private var keyColor: Color {
        return Color(red: 0.65, green: 0.45, blue: 0.9) // Key color (purple)
    }
}

// MARK: - Array Chunk View (Collapsible)

private struct ArrayChunkView: View {
    let startIndex: Int
    let endIndex: Int
    let elements: [ConsoleValue]
    @State private var isExpanded: Bool = false

    private var label: String {
        "[\(startIndex)...\(endIndex)]"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 10)

                    Text(label)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.blue)

                    Text("(\(elements.count) items)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)

                    Spacer()
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Content (expanded)
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(elements.enumerated()), id: \.offset) { localIdx, element in
                        let globalIdx = startIndex + localIdx
                        HStack(alignment: .top, spacing: 6) {
                            Text("[\(globalIdx)]")
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Color(red: 0.2, green: 0.4, blue: 0.8))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .padding(.leading, 4)

                            Text(":")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.tertiary)

                            ConsoleValueView(value: element)
                        }
                    }
                }
                .padding(.leading, 4)
                .padding(.vertical, 4)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let sample: ConsoleValue = .object(ConsoleObject(properties: [
        "name": .string("John Doe"),
        "age": .number(30),
        "isActive": .boolean(true),
        "email": .null,
        "hobbies": .array(ConsoleArray(elements: [
            .string("coding"),
            .string("reading"),
            .string("gaming")
        ])),
        "address": .object(ConsoleObject(properties: [
            "street": .string("123 Main St"),
            "city": .string("Seoul"),
            "country": .string("South Korea")
        ], depth: 1))
    ]))

    ScrollView {
        ConsoleValueView(value: sample)
            .padding()
    }
}
