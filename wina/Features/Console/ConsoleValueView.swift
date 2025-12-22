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
            typeBadge
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
            Button(action: { withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() } }) {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 10)

                    typeBadge

                    Text(value.preview)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(valueTextColor)
                        .textSelection(.enabled)

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Children (expanded)
            if isExpanded {
                children
                    .padding(.leading, 12)
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
                    HStack(alignment: .top, spacing: 6) {
                        Text(property.key)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: 150, alignment: .trailing)

                        Text(":")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.tertiary)

                        ConsoleValueView(value: property.value)
                    }
                }
            }

        case .array(let arr):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(arr.elements.enumerated()), id: \.offset) { index, element in
                    HStack(alignment: .top, spacing: 6) {
                        Text("[\(index)]")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: 150, alignment: .trailing)

                        Text(":")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.tertiary)

                        ConsoleValueView(value: element)
                    }
                }
            }

        case .map(let entries):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(entries.enumerated()), id: \.element.key) { _, entry in
                    HStack(alignment: .top, spacing: 6) {
                        Text(entry.key)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: 150, alignment: .trailing)

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
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: 150, alignment: .trailing)

                        ConsoleValueView(value: element)
                    }
                }
            }

        default:
            EmptyView()
        }
    }

    // MARK: - Type Badge

    private var typeBadge: some View {
        let (icon, label) = typeInfo
        return HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .semibold))
            Text(label)
                .font(.system(size: 9, weight: .medium))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(value.typeColor, in: RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Type Info (icon + label)

    private var typeInfo: (icon: String, label: String) {
        switch value {
        case .string: return ("quote.bubble.fill", "str")
        case .number: return ("number", "num")
        case .boolean: return ("checkmark.square.fill", "bool")
        case .null: return ("circle.slash", "null")
        case .undefined: return ("questionmark.circle.fill", "undefined")
        case .object: return ("curlybraces", "obj")
        case .array: return ("square.fill", "arr")
        case .function(let name): return ("function", "ƒ")
        case .date: return ("calendar", "date")
        case .domElement(let tag, _): return ("tag.fill", "<\(tag)>")
        case .map: return ("map.fill", "map")
        case .set: return ("circle.fill", "set")
        case .circularReference: return ("arrow.circlepath", "circular")
        case .error: return ("exclamationmark.triangle.fill", "err")
        }
    }

    // MARK: - Text Color

    private var valueTextColor: Color {
        switch value {
        case .error: return .red
        case .circularReference: return .orange
        default: return .primary
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
