//
//  NetworkTextViews.swift
//  wina
//
//  Selectable text views and JSON tree views for Network detail display.
//

import SwiftUI

// MARK: - Selectable Text View (UITextView Wrapper)

struct SelectableTextView: UIViewRepresentable {
    let text: String
    var font: UIFont = .monospacedSystemFont(ofSize: 11, weight: .regular)
    var textColor = UIColor.label
    var padding = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)

    func makeUIView(context: Context) -> AutoSizingTextView {
        let textView = AutoSizingTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.textContainerInset = padding
        textView.font = font
        textView.textColor = textColor
        textView.dataDetectorTypes = []
        textView.alwaysBounceVertical = false
        textView.isScrollEnabled = false

        // Wrap text properly
        textView.textContainer.lineBreakMode = .byWordWrapping
        textView.textContainer.widthTracksTextView = true

        return textView
    }

    func updateUIView(_ uiView: AutoSizingTextView, context: Context) {
        uiView.text = text
        uiView.font = font
        uiView.textColor = textColor
        uiView.textContainerInset = padding
        uiView.invalidateIntrinsicContentSize()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: AutoSizingTextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width > 0 else { return nil }
        let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: size.height)
    }
}

// Custom UITextView that properly calculates intrinsic content size
class AutoSizingTextView: UITextView {
    override var intrinsicContentSize: CGSize {
        let fixedWidth = bounds.width > 0 ? bounds.width : ScreenUtility.screenSize.width - 64
        let size = sizeThatFits(CGSize(width: fixedWidth, height: .greatestFiniteMagnitude))
        return CGSize(width: UIView.noIntrinsicMetric, height: size.height)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        invalidateIntrinsicContentSize()
    }
}

// MARK: - Searchable Text View

struct SearchableTextView: UIViewRepresentable {
    let text: String
    let searchText: String
    let currentMatchIndex: Int
    var font: UIFont = .monospacedSystemFont(ofSize: 11, weight: .regular)
    var textColor = UIColor.label
    var onMatchCountChanged: ((Int) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = true

        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        textView.dataDetectorTypes = []
        textView.isScrollEnabled = false
        textView.textContainer.lineBreakMode = .byWordWrapping
        textView.textContainer.widthTracksTextView = true
        textView.tag = 100

        scrollView.addSubview(textView)
        context.coordinator.scrollView = scrollView
        context.coordinator.textView = textView
        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        let coordinator = context.coordinator

        // Cancel previous search task
        coordinator.searchTask?.cancel()

        guard let textView = uiView.viewWithTag(100) as? UITextView else { return }

        // Capture values for background thread
        let text = self.text
        let searchText = self.searchText
        let currentMatchIndex = self.currentMatchIndex
        let font = self.font
        let textColor = self.textColor
        let onMatchCountChanged = self.onMatchCountChanged

        // Start new search task in background
        coordinator.searchTask = Task.detached(priority: .userInitiated) {
            // Find matches in background (local variable only used within this task)
            var localMatchRanges: [NSRange] = []
            if !searchText.isEmpty {
                let nsText = text as NSString
                var searchRange = NSRange(location: 0, length: nsText.length)

                while searchRange.location < nsText.length {
                    if Task.isCancelled { return }

                    let foundRange = nsText.range(
                        of: searchText,
                        options: .caseInsensitive,
                        range: searchRange
                    )
                    if foundRange.location != NSNotFound {
                        localMatchRanges.append(foundRange)
                        searchRange.location = foundRange.location + foundRange.length
                        searchRange.length = nsText.length - searchRange.location
                    } else {
                        break
                    }
                }
            }

            if Task.isCancelled { return }

            // Capture final match ranges for MainActor
            let matchRanges = localMatchRanges

            // Update UI on main thread (build attributed string here to avoid Sendable issues)
            await MainActor.run {
                let attributedText = NSMutableAttributedString(
                    string: text,
                    attributes: [
                        .font: font,
                        .foregroundColor: textColor
                    ]
                )

                for (index, range) in matchRanges.enumerated() {
                    let isCurrentMatch = index == currentMatchIndex
                    attributedText.addAttributes([
                        .backgroundColor: isCurrentMatch
                            ? UIColor.systemYellow
                            : UIColor.systemYellow.withAlphaComponent(0.3)
                    ], range: range)
                }

                textView.attributedText = attributedText

                // Update layout
                let width = uiView.bounds.width > 0 ? uiView.bounds.width : ScreenUtility.screenSize.width - 64
                let textSize = textView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
                textView.frame = CGRect(origin: .zero, size: CGSize(width: width, height: textSize.height))
                uiView.contentSize = textView.frame.size

                // Report match count
                onMatchCountChanged?(matchRanges.count)

                // Scroll to current match
                if !matchRanges.isEmpty && currentMatchIndex < matchRanges.count {
                    let targetRange = matchRanges[currentMatchIndex]
                    if let start = textView.position(from: textView.beginningOfDocument, offset: targetRange.location),
                       let end = textView.position(from: start, offset: targetRange.length),
                       let textRange = textView.textRange(from: start, to: end) {
                        let rect = textView.firstRect(for: textRange)
                        let scrollRect = rect.insetBy(dx: 0, dy: -50)
                        uiView.scrollRectToVisible(scrollRect, animated: true)
                    }
                }
            }
        }
    }

    class Coordinator {
        weak var scrollView: UIScrollView?
        weak var textView: UITextView?
        var searchTask: Task<Void, Never>?

        deinit {
            searchTask?.cancel()
        }
    }
}

// MARK: - JSON Tree View (Chrome DevTools Style)

enum JSONNode: Identifiable {
    case null(key: String?)
    case bool(key: String?, value: Bool)
    case number(key: String?, value: Double)
    case string(key: String?, value: String)
    case array(key: String?, values: [JSONNode])
    case object(key: String?, pairs: [(String, JSONNode)])

    var id: String {
        switch self {
        case .null(let key): return "null-\(key ?? "root")-\(UUID().uuidString)"
        case .bool(let key, _): return "bool-\(key ?? "root")-\(UUID().uuidString)"
        case .number(let key, _): return "number-\(key ?? "root")-\(UUID().uuidString)"
        case .string(let key, _): return "string-\(key ?? "root")-\(UUID().uuidString)"
        case .array(let key, _): return "array-\(key ?? "root")-\(UUID().uuidString)"
        case .object(let key, _): return "object-\(key ?? "root")-\(UUID().uuidString)"
        }
    }

    var key: String? {
        switch self {
        case .null(let key), .bool(let key, _), .number(let key, _),
             .string(let key, _), .array(let key, _), .object(let key, _):
            return key
        }
    }

    var isExpandable: Bool {
        switch self {
        case .array, .object: return true
        default: return false
        }
    }

    var childCount: Int {
        switch self {
        case .array(_, let values): return values.count
        case .object(_, let pairs): return pairs.count
        default: return 0
        }
    }

    static func parse(_ json: Any, key: String? = nil) -> JSONNode {
        switch json {
        case is NSNull:
            return .null(key: key)
        case let bool as Bool:
            return .bool(key: key, value: bool)
        case let number as NSNumber:
            return .number(key: key, value: number.doubleValue)
        case let string as String:
            return .string(key: key, value: string)
        case let array as [Any]:
            let nodes = array.enumerated().map { parse($1, key: "[\($0)]") }
            return .array(key: key, values: nodes)
        case let dict as [String: Any]:
            let pairs = dict.sorted { $0.key < $1.key }.map { ($0.key, parse($0.value, key: $0.key)) }
            return .object(key: key, pairs: pairs)
        default:
            return .string(key: key, value: String(describing: json))
        }
    }
}

struct JSONTreeView: View {
    let jsonString: String

    var body: some View {
        if let data = jsonString.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) {
            let rootNode = JSONNode.parse(json)
            ScrollView(.horizontal, showsIndicators: false) {
                JSONNodeView(node: rootNode, depth: 0, isLast: true)
                    .padding(12)
            }
        } else {
            Text("Invalid JSON")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(12)
        }
    }
}

struct JSONNodeView: View {
    let node: JSONNode
    let depth: Int
    let isLast: Bool
    @State private var isExpanded: Bool = false

    // Auto-expand first level
    init(node: JSONNode, depth: Int, isLast: Bool) {
        self.node = node
        self.depth = depth
        self.isLast = isLast
        self._isExpanded = State(initialValue: depth == 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Current node row
            HStack(spacing: 0) {
                // Expand/collapse button for expandable nodes
                if node.isExpandable {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.primary.opacity(0.6))
                            .frame(width: 20, height: 20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else {
                    Spacer().frame(width: 20)
                }

                // Key (if exists) - Chrome DevTools style: plain text
                if let key = node.key {
                    Text(key)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.primary)
                    Text(": ")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                // Value or preview
                valueView
            }
            .frame(minHeight: 20)

            // Children (if expanded)
            if isExpanded {
                childrenView
            }
        }
        .padding(.leading, CGFloat(depth) * 10)
    }

    // Chrome DevTools style: strings = red, primitives = blue, containers = gray
    private let primitiveColor = Color(red: 0.0, green: 0.45, blue: 0.73)  // Blue
    private let stringColor = Color(red: 0.77, green: 0.1, blue: 0.09)     // Red

    @ViewBuilder
    private var valueView: some View {
        switch node {
        case .null:
            Text("null")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(primitiveColor)
        case .bool(_, let value):
            Text(value ? "true" : "false")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(primitiveColor)
        case .number(_, let value):
            Text(formatNumber(value))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(primitiveColor)
        case .string(_, let value):
            Text("\"\(value)\"")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(stringColor)
                .lineLimit(isExpanded ? nil : 1)
        case .array(_, let values):
            Text("Array[\(values.count)]")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.primary.opacity(0.5))
        case .object(_, let pairs):
            Text("Object{\(pairs.count)}")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.primary.opacity(0.5))
        }
    }

    @ViewBuilder
    private var childrenView: some View {
        switch node {
        case .array(_, let values):
            ForEach(Array(values.enumerated()), id: \.offset) { index, childNode in
                JSONNodeView(
                    node: childNode,
                    depth: depth + 1,
                    isLast: index == values.count - 1
                )
            }
        case .object(_, let pairs):
            ForEach(Array(pairs.enumerated()), id: \.offset) { index, pair in
                JSONNodeView(
                    node: pair.1,
                    depth: depth + 1,
                    isLast: index == pairs.count - 1
                )
            }
        default:
            EmptyView()
        }
    }

    private func formatNumber(_ value: Double) -> String {
        if value == value.rounded() && abs(value) < 1e15 {
            return String(format: "%.0f", value)
        }
        return String(value)
    }
}
