import Foundation
import SwiftUI

// MARK: - Console Value Model

/// 콘솔에 출력되는 모든 값의 타입을 표현합니다.
/// JavaScript의 동적 타입 시스템을 Swift의 타입-안전 enum으로 모델링합니다.
indirect enum ConsoleValue {
    case string(String)
    case number(Double)
    case boolean(Bool)
    case null
    case undefined
    case object(ConsoleObject)
    case array(ConsoleArray)
    case function(name: String)
    case date(Date)
    case domElement(tag: String, attributes: [String: String])
    case map(entries: [(key: String, value: ConsoleValue)])
    case set(values: [ConsoleValue])
    case circularReference(String)
    case error(message: String)

    /// 콘솔에서 한 줄로 표시되는 미리보기 텍스트
    var preview: String {
        switch self {
        case .string(let s):
            return "\"\(s)\""
        case .number(let n):
            if n == Double(Int(n)) {
                return String(Int(n))
            }
            return String(n)
        case .boolean(let b):
            return b ? "true" : "false"
        case .null:
            return "null"
        case .undefined:
            return "undefined"
        case .object(let obj):
            let count = obj.properties.count
            return count == 0 ? "{}" : "{ \(count) properties }"
        case .array(let arr):
            let count = arr.totalCount
            return count == 0 ? "[]" : "[ \(count) items ]"
        case .function(let name):
            return "ƒ \(name)()"
        case .date(let date):
            return "Date \(date.formatted())"
        case .domElement(let tag, _):
            return "<\(tag)>"
        case .map(let entries):
            return "Map(\(entries.count)) { ... }"
        case .set(let values):
            return "Set(\(values.count)) { ... }"
        case .circularReference(let path):
            return "[Circular \(path)]"
        case .error(let message):
            return "Error: \(message)"
        }
    }

    /// 색상 표현 (타입별 기본 색상)
    var typeColor: Color {
        switch self {
        case .string: return .green
        case .number: return .cyan
        case .boolean: return .yellow
        case .null, .undefined: return .gray
        case .object, .array, .map, .set: return .blue
        case .function: return .orange
        case .date: return .purple
        case .domElement: return .red
        case .circularReference: return .gray
        case .error: return .red
        }
    }

    /// 확장 가능 여부 (자식 요소가 있는가)
    var isExpandable: Bool {
        switch self {
        case .object, .array, .map, .set:
            return true
        default:
            return false
        }
    }
}

// MARK: - Console Object Model

/// JavaScript 객체를 표현하는 모델
struct ConsoleObject: Equatable {
    let properties: [String: ConsoleValue]
    let depth: Int  // 트리의 깊이 (무한 재귀 방지)
    let maxDepth: Int = 3  // 자동 펼치기의 최대 깊이

    var shouldAutoExpand: Bool {
        depth < maxDepth
    }

    init(properties: [String: ConsoleValue], depth: Int = 0) {
        self.properties = properties
        self.depth = depth
    }

    /// 정렬된 프로퍼티 (보기 좋게)
    var sortedProperties: [(key: String, value: ConsoleValue)] {
        properties.sorted { $0.key < $1.key }
    }
}

// MARK: - Console Array Model

/// JavaScript 배열을 표현하는 모델
struct ConsoleArray: Equatable {
    let elements: [ConsoleValue]
    let depth: Int
    let maxDepth: Int = 3
    let totalCount: Int
    let isTruncated: Bool

    var shouldAutoExpand: Bool {
        depth < maxDepth
    }

    init(elements: [ConsoleValue], depth: Int = 0, totalCount: Int? = nil, isTruncated: Bool = false) {
        self.elements = elements
        self.depth = depth
        self.totalCount = totalCount ?? elements.count
        self.isTruncated = isTruncated
    }
}

// MARK: - Console Styled Segment

/// console.log("%c...") 스타일링 정보를 담는 모델
struct ConsoleStyledSegment: Equatable, Identifiable {
    let id = UUID()
    let text: String
    let color: Color?
    let backgroundColor: Color?
    let isBold: Bool
    let fontSize: CGFloat?
    let fontStyle: Font.Design?

    init(
        text: String,
        color: Color? = nil,
        backgroundColor: Color? = nil,
        isBold: Bool = false,
        fontSize: CGFloat? = nil,
        fontStyle: Font.Design? = nil
    ) {
        self.text = text
        self.color = color
        self.backgroundColor = backgroundColor
        self.isBold = isBold
        self.fontSize = fontSize
        self.fontStyle = fontStyle
    }
}

// MARK: - Factory Methods

extension ConsoleValue {
    /// JavaScript 객체를 ConsoleValue로 변환
    static func fromObject(
        _ dict: [String: Any],
        depth: Int = 0,
        seenObjects: inout Set<String>
    ) -> ConsoleValue {
        let maxDepth = 3
        if depth >= maxDepth {
            return .object(ConsoleObject(properties: [:], depth: depth))
        }

        var properties: [String: ConsoleValue] = [:]
        for (key, value) in dict {
            let identifier = "\(ObjectIdentifier(value as AnyObject))"
            if seenObjects.contains(identifier) {
                properties[key] = .circularReference(key)
            } else {
                seenObjects.insert(identifier)
                properties[key] = ConsoleValue.fromAny(value, depth: depth + 1, seenObjects: &seenObjects)
            }
        }

        return .object(ConsoleObject(properties: properties, depth: depth))
    }

    /// JavaScript 배열을 ConsoleValue로 변환
    static func fromArray(
        _ arr: [Any],
        depth: Int = 0,
        seenObjects: inout Set<String>
    ) -> ConsoleValue {
        let maxDepth = 3
        if depth >= maxDepth {
            return .array(ConsoleArray(elements: [], depth: depth))
        }

        let elements = arr.map { item in
            ConsoleValue.fromAny(item, depth: depth + 1, seenObjects: &seenObjects)
        }

        return .array(ConsoleArray(elements: elements, depth: depth))
    }

    /// 임의의 값을 ConsoleValue로 변환
    static func fromAny(
        _ value: Any,
        depth: Int = 0,
        seenObjects: inout Set<String>
    ) -> ConsoleValue {
        let maxDepth = 3
        if depth >= maxDepth {
            return .string(String(describing: value))
        }

        switch value {
        case let str as String:
            return .string(str)
        case let num as NSNumber:
            if NSStringFromClass(type(of: num)) == "__NSCFBoolean" {
                return .boolean(num.boolValue)
            }
            return .number(num.doubleValue)
        case let bool as Bool:
            return .boolean(bool)
        case is NSNull:
            return .null
        case let date as Date:
            return .date(date)
        case let dict as [String: Any]:
            var seen = seenObjects
            return fromObject(dict, depth: depth, seenObjects: &seen)
        case let arr as [Any]:
            var seen = seenObjects
            return fromArray(arr, depth: depth, seenObjects: &seen)
        default:
            return .string(String(describing: value))
        }
    }

    /// Serialized payload를 ConsoleValue로 변환 (WebView console hook)
    static func fromSerializedAny(_ value: Any, depth: Int = 0) -> ConsoleValue? {
        let maxDepth = 3
        if depth >= maxDepth {
            return .string("[Max Depth]")
        }

        guard let dict = value as? [String: Any],
              let type = dict["type"] as? String else {
            return nil
        }

        switch type {
        case "null":
            return .null
        case "undefined":
            return .undefined
        case "boolean":
            return .boolean(dict["value"] as? Bool ?? false)
        case "number":
            if let number = dict["value"] as? NSNumber {
                return .number(number.doubleValue)
            }
            return .number(0)
        case "string":
            return .string(dict["value"] as? String ?? "")
        case "function":
            return .function(name: dict["name"] as? String ?? "anonymous")
        case "date":
            if let value = dict["value"] as? String,
               let date = ISO8601DateFormatter().date(from: value) {
                return .date(date)
            }
            return .string(dict["value"] as? String ?? "Invalid Date")
        case "array":
            let items = dict["items"] as? [Any] ?? []
            let elements = items.compactMap { fromSerializedAny($0, depth: depth + 1) }
            let totalCount = dict["length"] as? Int
            let isTruncated = dict["truncated"] as? Bool ?? false
            return .array(ConsoleArray(elements: elements, depth: depth, totalCount: totalCount, isTruncated: isTruncated))
        case "object":
            let props = dict["properties"] as? [String: Any] ?? [:]
            var properties: [String: ConsoleValue] = [:]
            for (key, raw) in props {
                if let parsed = fromSerializedAny(raw, depth: depth + 1) {
                    properties[key] = parsed
                }
            }
            if dict["truncated"] as? Bool == true {
                properties["[[Truncated]]"] = .string("true")
            }
            return .object(ConsoleObject(properties: properties, depth: depth))
        case "map":
            let entriesRaw = dict["entries"] as? [[String: Any]] ?? []
            let entries: [(key: String, value: ConsoleValue)] = entriesRaw.compactMap { entry in
                guard let valueRaw = entry["value"] else { return nil }
                let keyString = entry["keyString"] as? String ?? "key"
                guard let valueParsed = fromSerializedAny(valueRaw, depth: depth + 1) else { return nil }
                return (key: keyString, value: valueParsed)
            }
            return .map(entries: entries)
        case "set":
            let valuesRaw = dict["values"] as? [Any] ?? []
            let values = valuesRaw.compactMap { fromSerializedAny($0, depth: depth + 1) }
            return .set(values: values)
        case "error":
            let message = dict["message"] as? String ?? "Error"
            let stack = dict["stack"] as? String
            if let stack, !stack.isEmpty {
                return .error(message: "\(message)\n\(stack)")
            }
            return .error(message: message)
        case "dom":
            let tag = dict["tag"] as? String ?? "element"
            let attributes = dict["attributes"] as? [String: String] ?? [:]
            return .domElement(tag: tag, attributes: attributes)
        case "symbol":
            return .string(dict["value"] as? String ?? "Symbol()")
        case "bigint":
            return .string(dict["value"] as? String ?? "0n")
        case "circular":
            return .circularReference(dict["path"] as? String ?? "root")
        default:
            return .string(String(describing: dict["value"] ?? type))
        }
    }
}

// MARK: - Equatable Conformance

extension ConsoleValue: Equatable {
    static func == (lhs: ConsoleValue, rhs: ConsoleValue) -> Bool {
        switch (lhs, rhs) {
        case let (.string(l), .string(r)):
            return l == r
        case let (.number(l), .number(r)):
            return l == r
        case let (.boolean(l), .boolean(r)):
            return l == r
        case (.null, .null), (.undefined, .undefined):
            return true
        case let (.object(l), .object(r)):
            return l == r
        case let (.array(l), .array(r)):
            return l == r
        case let (.function(l), .function(r)):
            return l == r
        case let (.date(l), .date(r)):
            return l == r
        case let (.domElement(lTag, lAttrs), .domElement(rTag, rAttrs)):
            return lTag == rTag && lAttrs == rAttrs
        case let (.map(lEntries), .map(rEntries)):
            return lEntries.count == rEntries.count &&
                zip(lEntries, rEntries).allSatisfy { $0.key == $1.key && $0.value == $1.value }
        case let (.set(l), .set(r)):
            return l.count == r.count && zip(l, r).allSatisfy { $0 == $1 }
        case let (.circularReference(l), .circularReference(r)):
            return l == r
        case let (.error(l), .error(r)):
            return l == r
        default:
            return false
        }
    }
}
