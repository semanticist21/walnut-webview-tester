import Foundation

// MARK: - JSON Node Model

/// Represents a node in a JSON tree structure
struct JsonNode: Identifiable {
    let key: String?
    let value: JsonValue
    let depth: Int
    let path: [String]  // JSON path for CRUD operations

    init(key: String?, value: JsonValue, depth: Int, path: [String] = []) {
        self.key = key
        self.value = value
        self.depth = depth
        self.path = path
    }

    /// Stable ID based on path for consistent expand/collapse state
    var id: String {
        path.isEmpty ? "root" : path.joined(separator: ".")
    }

    var displayKey: String {
        key ?? ""
    }

    /// Full path string for display (e.g., "user.profile.name")
    var pathString: String {
        path.joined(separator: ".")
    }

    var isExpandable: Bool {
        switch value {
        case .object, .array:
            return true
        default:
            return false
        }
    }

    var children: [JsonNode]? {
        switch value {
        case let .object(dict):
            return dict
                .map { JsonNode(key: $0.key, value: $0.value, depth: depth + 1, path: path + [$0.key]) }
                .sorted { $0.displayKey < $1.displayKey }
        case let .array(arr):
            return arr.enumerated().map {
                JsonNode(key: "[\($0.offset)]", value: $0.element, depth: depth + 1, path: path + ["[\($0.offset)]"])
            }
        default:
            return nil
        }
    }

    /// Whether this node is inside an array
    var isArrayElement: Bool {
        key?.hasPrefix("[") == true && key?.hasSuffix("]") == true
    }

    /// Parent type based on path (for CRUD operations)
    var parentIsArray: Bool {
        guard let lastPath = path.last else { return false }
        return lastPath.hasPrefix("[") && lastPath.hasSuffix("]")
    }

    var typeColor: JsonTypeColor {
        switch value {
        case .object: return .object
        case .array: return .array
        case .string: return .string
        case .number: return .number
        case .bool: return .bool
        case .null: return .null
        }
    }

    var displayValue: String {
        switch value {
        case let .object(dict):
            return "{\(dict.count) items}"
        case let .array(arr):
            return "[\(arr.count) items]"
        case let .string(str):
            return "\"\(str)\""
        case let .number(num):
            if num.truncatingRemainder(dividingBy: 1) == 0 {
                return String(format: "%.0f", num)
            }
            return String(num)
        case let .bool(val):
            return val ? "true" : "false"
        case .null:
            return "null"
        }
    }

    var rawValue: String {
        switch value {
        case let .string(str): return str
        case let .number(num):
            if num.truncatingRemainder(dividingBy: 1) == 0 {
                return String(format: "%.0f", num)
            }
            return String(num)
        case let .bool(val): return val ? "true" : "false"
        case .null: return "null"
        case .object, .array:
            if let data = try? JSONSerialization.data(
                withJSONObject: value.toFoundation(),
                options: [.prettyPrinted, .sortedKeys]
            ),
                let str = String(data: data, encoding: .utf8)
            {
                return str
            }
            return ""
        }
    }
}

// MARK: - JSON Value Enum

enum JsonValue {
    case object([String: JsonValue])
    case array([JsonValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    func toFoundation() -> Any {
        switch self {
        case let .object(dict):
            return dict.mapValues { $0.toFoundation() }
        case let .array(arr):
            return arr.map { $0.toFoundation() }
        case let .string(str):
            return str
        case let .number(num):
            return num
        case let .bool(val):
            return val
        case .null:
            return NSNull()
        }
    }
}

// MARK: - JSON Type Colors

enum JsonTypeColor {
    case object
    case array
    case string
    case number
    case bool
    case null

    var foreground: String {
        switch self {
        case .object: return "purple"
        case .array: return "orange"
        case .string: return "green"
        case .number: return "blue"
        case .bool: return "cyan"
        case .null: return "gray"
        }
    }
}
