import SwiftUI

// MARK: - Console Value View

/// ConsoleValue 객체를 트리 형태로 렌더링하는 뷰 (확장/축소 가능)
/// 각 행(row)에만 depth 기반 padding 적용, children은 별도 padding 없음
struct ConsoleValueView: View {
    let value: ConsoleValue
    let depth: Int
    let key: String?
    let isPrototype: Bool
    @State private var isExpanded: Bool = false

    init(value: ConsoleValue, depth: Int = 0, key: String? = nil, isPrototype: Bool = false) {
        self.value = value
        self.depth = depth
        self.key = key
        self.isPrototype = isPrototype
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Row: [chevron] [key:] [value/preview] - 이 행에만 padding 적용
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                // Chevron for expandable
                if value.isExpandable {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 10, height: 14, alignment: .center)
                } else {
                    Spacer().frame(width: 10, height: 14)
                }

                // Key (if present)
                if let key = key {
                    Text(key)
                        .font(.system(size: 12, weight: isPrototype ? .regular : .semibold, design: .monospaced))
                        .foregroundStyle(isPrototype ? .secondary : keyColor)
                        .italic(isPrototype)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)

                    Text(":")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }

                // Value or preview
                Text(value.preview)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(valueTextColor)
                    .lineLimit(5)
                    .textSelection(.enabled)

                Spacer()
            }
            .padding(.leading, CGFloat(depth) * 10)  // 행(row)에만 padding
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                guard value.isExpandable else { return }
                withAnimation(.easeInOut(duration: 0.15)) {
                    isExpanded.toggle()
                }
            }

            // Children (expanded) - VStack 밖에서 각자 자신의 padding 적용
            if isExpanded {
                children
            }
        }
        // 외부 VStack에는 padding 없음 - children이 자신의 depth로 padding 적용
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
                    elements: Array(allElements[chunk.0...chunk.1]),
                    depth: depth + 1
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
                    let isProto = property.key == "[[Prototype]]"
                    let isTruncated = property.key == "[[Truncated]]"

                    if isTruncated {
                        Text("… truncated properties")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .padding(.leading, CGFloat(depth + 1) * 10)
                    } else {
                        ConsoleValueView(
                            value: property.value,
                            depth: depth + 1,
                            key: property.key,
                            isPrototype: isProto
                        )
                    }
                }
            }

        case .domElement(let tag, let attributes):
            VStack(alignment: .leading, spacing: 4) {
                let items = domProperties(tag: tag, attributes: attributes)
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    ConsoleValueView(
                        value: item.value,
                        depth: depth + 1,
                        key: item.key
                    )
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
                        ConsoleValueView(
                            value: element,
                            depth: depth + 1,
                            key: "[\(index)]"
                        )
                    }
                }

                if arr.isTruncated, arr.totalCount > arr.elements.count {
                    Text("… \(arr.totalCount - arr.elements.count) more items")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .padding(.leading, CGFloat(depth + 1) * 10)
                }
            }

        case .map(let entries):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(entries.enumerated()), id: \.element.key) { _, entry in
                    MapEntryView(
                        entryKey: entry.key,
                        entryValue: entry.value,
                        depth: depth + 1
                    )
                }
            }

        case .set(let values):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(values.enumerated()), id: \.offset) { index, element in
                    ConsoleValueView(
                        value: element,
                        depth: depth + 1,
                        key: "(\(index))"
                    )
                }
            }

        default:
            EmptyView()
        }
    }

    private func domProperties(tag: String, attributes: [String: String]) -> [(key: String, value: ConsoleValue)] {
        var items: [(String, ConsoleValue)] = [("tag", .string(tag))]
        let sorted = attributes.sorted { $0.key < $1.key }
        for (key, value) in sorted {
            items.append((key, .string(value)))
        }
        return items
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

// MARK: - Map Entry View (uses → instead of :)

private struct MapEntryView: View {
    let entryKey: String
    let entryValue: ConsoleValue
    let depth: Int
    @State private var isExpanded: Bool = false

    private var keyColor: Color {
        return Color(red: 0.65, green: 0.45, blue: 0.9)
    }

    private var valueTextColor: Color {
        switch entryValue {
        case .error: return Color(red: 1.0, green: 0.2, blue: 0.2)
        case .circularReference: return Color(red: 1.0, green: 0.7, blue: 0.0)
        case .string: return Color(red: 0.9, green: 0.6, blue: 0.0)
        case .number: return Color(red: 0.2, green: 0.7, blue: 1.0)
        case .boolean: return Color(red: 0.8, green: 0.2, blue: 0.8)
        case .null, .undefined: return Color(red: 0.7, green: 0.7, blue: 0.7)
        default: return .primary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Row with padding
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if entryValue.isExpandable {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 10, height: 14, alignment: .center)
                } else {
                    Spacer().frame(width: 10, height: 14)
                }

                Text(entryKey)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(keyColor)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                Text("→")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.tertiary)

                Text(entryValue.preview)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(valueTextColor)
                    .lineLimit(5)
                    .textSelection(.enabled)

                Spacer()
            }
            .padding(.leading, CGFloat(depth) * 10)  // 행에만 padding
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                guard entryValue.isExpandable else { return }
                withAnimation(.easeInOut(duration: 0.15)) {
                    isExpanded.toggle()
                }
            }

            // Children - 외부 VStack에 padding 없음
            if isExpanded {
                ConsoleValueView(value: entryValue, depth: depth + 1)
            }
        }
        // 외부 VStack에는 padding 없음
    }
}

// MARK: - Array Chunk View (Collapsible)

private struct ArrayChunkView: View {
    let startIndex: Int
    let endIndex: Int
    let elements: [ConsoleValue]
    let depth: Int
    @State private var isExpanded: Bool = false

    private var label: String {
        "[\(startIndex)...\(endIndex)]"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with padding
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 10, height: 14, alignment: .center)

                    Text(label)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.blue)

                    Text("(\(elements.count) items)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)

                    Spacer()
                }
                .padding(.leading, CGFloat(depth) * 10)  // 행에만 padding
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Content (expanded) - 외부 VStack에 padding 없음
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(elements.enumerated()), id: \.offset) { localIdx, element in
                        let globalIdx = startIndex + localIdx
                        ConsoleValueView(
                            value: element,
                            depth: depth + 1,
                            key: "[\(globalIdx)]"
                        )
                    }
                }
                .padding(.vertical, 4)
            }
        }
        // 외부 VStack에는 padding 없음
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
