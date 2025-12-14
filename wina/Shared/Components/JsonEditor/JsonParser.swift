import Foundation

// MARK: - JSON Parser

enum JsonParser {
    /// Parse result containing either a valid JSON node or an error
    struct ParseResult {
        let node: JsonNode?
        let error: ParseError?
        let isValid: Bool

        static func success(_ node: JsonNode) -> ParseResult {
            ParseResult(node: node, error: nil, isValid: true)
        }

        static func failure(_ error: ParseError) -> ParseResult {
            ParseResult(node: nil, error: error, isValid: false)
        }

        static let empty = ParseResult(node: nil, error: nil, isValid: false)
    }

    struct ParseError {
        let message: String
        let position: Int?
        let line: Int?
        let column: Int?

        var displayMessage: String {
            if let line, let column {
                return "Line \(line), Col \(column): \(message)"
            }
            return message
        }
    }

    /// Check if a string is valid JSON
    static func isValidJson(_ string: String) -> Bool {
        guard !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        guard let data = string.data(using: .utf8) else {
            return false
        }
        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }

    /// Parse a JSON string into a JsonNode tree
    static func parse(_ string: String) -> ParseResult {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .empty
        }

        guard let data = trimmed.data(using: .utf8) else {
            return .failure(ParseError(message: "Invalid UTF-8 encoding", position: nil, line: nil, column: nil))
        }

        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
            let value = convertToJsonValue(jsonObject)
            let rootNode = JsonNode(key: nil, value: value, depth: 0)
            return .success(rootNode)
        } catch let error as NSError {
            let message = parseNSErrorMessage(error)
            return .failure(message)
        }
    }

    /// Format JSON string with pretty printing
    static func prettyPrint(_ string: String) -> String? {
        guard let data = string.data(using: .utf8),
            let jsonObject = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed),
            let prettyData = try? JSONSerialization.data(
                withJSONObject: jsonObject,
                options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            ),
            let prettyString = String(data: prettyData, encoding: .utf8)
        else {
            return nil
        }
        return prettyString
    }

    /// Minify JSON string
    static func minify(_ string: String) -> String? {
        guard let data = string.data(using: .utf8),
            let jsonObject = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed),
            let minifiedData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.sortedKeys]),
            let minifiedString = String(data: minifiedData, encoding: .utf8)
        else {
            return nil
        }
        return minifiedString
    }

    // MARK: - CRUD Operations

    /// Add a key-value pair to an object at the given path
    static func addToObject(_ jsonString: String, at path: [String], key: String, value: Any) -> String? {
        guard var jsonObject = parseToFoundation(jsonString) else { return nil }

        if path.isEmpty {
            // Adding to root object
            guard var rootDict = jsonObject as? [String: Any] else { return nil }
            rootDict[key] = value
            return serialize(rootDict)
        }

        // Navigate to parent and add
        jsonObject = setValueAtPath(in: jsonObject, path: path, key: key, value: value, operation: .addToObject)
        return serialize(jsonObject)
    }

    /// Append an item to an array at the given path
    static func appendToArray(_ jsonString: String, at path: [String], value: Any) -> String? {
        guard var jsonObject = parseToFoundation(jsonString) else { return nil }

        if path.isEmpty {
            // Appending to root array
            guard var rootArray = jsonObject as? [Any] else { return nil }
            rootArray.append(value)
            return serialize(rootArray)
        }

        // Navigate to parent and append
        jsonObject = setValueAtPath(in: jsonObject, path: path, key: nil, value: value, operation: .appendToArray)
        return serialize(jsonObject)
    }

    /// Delete a key from an object or an item from an array
    static func delete(_ jsonString: String, at path: [String]) -> String? {
        guard !path.isEmpty else { return nil }  // Can't delete root
        guard var jsonObject = parseToFoundation(jsonString) else { return nil }

        jsonObject = setValueAtPath(in: jsonObject, path: path, key: nil, value: nil, operation: .delete)
        return serialize(jsonObject)
    }

    /// Update a value at the given path
    static func update(_ jsonString: String, at path: [String], value: Any) -> String? {
        guard !path.isEmpty else {
            // Replacing entire root
            return serialize(value)
        }
        guard var jsonObject = parseToFoundation(jsonString) else { return nil }

        jsonObject = setValueAtPath(in: jsonObject, path: path, key: nil, value: value, operation: .update)
        return serialize(jsonObject)
    }

    private enum CRUDOperation {
        case addToObject
        case appendToArray
        case delete
        case update
    }

    private static func setValueAtPath(
        in object: Any,
        path: [String],
        key: String?,
        value: Any?,
        operation: CRUDOperation
    ) -> Any {
        guard !path.isEmpty else { return object }

        let currentKey = path[0]
        let remainingPath = Array(path.dropFirst())

        // Handle array index notation [n]
        if currentKey.hasPrefix("["), currentKey.hasSuffix("]"),
           let indexStr = currentKey.dropFirst().dropLast().description as String?,
           let index = Int(indexStr),
           var array = object as? [Any], index < array.count
        {
            if remainingPath.isEmpty {
                switch operation {
                case .delete:
                    array.remove(at: index)
                case .update:
                    if let value { array[index] = value }
                case .appendToArray:
                    if let value, var nestedArray = array[index] as? [Any] {
                        nestedArray.append(value)
                        array[index] = nestedArray
                    }
                case .addToObject:
                    if let key, let value, var nestedDict = array[index] as? [String: Any] {
                        nestedDict[key] = value
                        array[index] = nestedDict
                    }
                }
            } else {
                array[index] = setValueAtPath(in: array[index], path: remainingPath, key: key, value: value, operation: operation)
            }
            return array
        }

        // Handle object key
        guard var dict = object as? [String: Any] else { return object }

        if remainingPath.isEmpty {
            switch operation {
            case .delete:
                dict.removeValue(forKey: currentKey)
            case .update:
                if let value { dict[currentKey] = value }
            case .appendToArray:
                if let value, var nestedArray = dict[currentKey] as? [Any] {
                    nestedArray.append(value)
                    dict[currentKey] = nestedArray
                }
            case .addToObject:
                if let key, let value, var nestedDict = dict[currentKey] as? [String: Any] {
                    nestedDict[key] = value
                    dict[currentKey] = nestedDict
                }
            }
        } else if let existing = dict[currentKey] {
            dict[currentKey] = setValueAtPath(in: existing, path: remainingPath, key: key, value: value, operation: operation)
        }

        return dict
    }

    private static func parseToFoundation(_ string: String) -> Any? {
        guard let data = string.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
    }

    private static func serialize(_ object: Any) -> String? {
        guard let data = try? JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        ) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Private Helpers

    private static func convertToJsonValue(_ object: Any) -> JsonValue {
        switch object {
        case let dict as [String: Any]:
            return .object(dict.mapValues { convertToJsonValue($0) })
        case let array as [Any]:
            return .array(array.map { convertToJsonValue($0) })
        case let string as String:
            return .string(string)
        case let number as NSNumber:
            if CFBooleanGetTypeID() == CFGetTypeID(number) {
                return .bool(number.boolValue)
            }
            return .number(number.doubleValue)
        case is NSNull:
            return .null
        default:
            return .string(String(describing: object))
        }
    }

    private static func parseNSErrorMessage(_ error: NSError) -> ParseError {
        let description = error.localizedDescription

        // Extract line/column from error message if available
        // Format: "... around line X, column Y."
        let linePattern = /line (\d+)/
        let columnPattern = /column (\d+)/

        let line = description.firstMatch(of: linePattern).map { Int($0.1)! }
        let column = description.firstMatch(of: columnPattern).map { Int($0.1)! }

        // Clean up error message
        var message = description
        if let range = message.range(of: "The data couldn't be read because ") {
            message = String(message[range.upperBound...])
        }

        return ParseError(message: message, position: nil, line: line, column: column)
    }
}

// MARK: - JSON Templates

enum JsonTemplate: String, CaseIterable {
    case emptyObject = "Empty Object"
    case emptyArray = "Empty Array"
    case keyValue = "Key-Value"
    case arrayWithItems = "Array with Items"

    var content: String {
        switch self {
        case .emptyObject:
            return "{}"
        case .emptyArray:
            return "[]"
        case .keyValue:
            return """
                {
                  "key": "value"
                }
                """
        case .arrayWithItems:
            return """
                [
                  "item1",
                  "item2"
                ]
                """
        }
    }

    var icon: String {
        switch self {
        case .emptyObject, .keyValue:
            return "curlybraces"
        case .emptyArray, .arrayWithItems:
            return "brackets"
        }
    }
}
