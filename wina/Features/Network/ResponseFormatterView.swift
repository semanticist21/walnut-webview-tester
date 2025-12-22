//
//  ResponseFormatterView.swift
//  wina
//
//  Response body formatting with syntax highlighting for multiple content types.
//  Supports JSON (pretty-print + colors), HTML/XML (syntax highlighting), images, and plain text.
//

import SwiftUI

// MARK: - Response Formatter View

struct ResponseFormatterView: View {
    let responseBody: String
    let contentType: ResponseContentType

    var body: some View {
        switch contentType {
        case .json:
            JSONFormattedView(jsonString: responseBody)
        case .html:
            HTMLFormattedView(htmlString: responseBody)
        case .xml:
            XMLFormattedView(xmlString: responseBody)
        case .image:
            ImagePreviewView(base64String: responseBody)
        case .text, .css, .javascript:
            PlainTextView(text: responseBody, language: contentType)
        default:
            PlainTextView(text: responseBody, language: .text)
        }
    }
}

// MARK: - Response Content Type

enum ResponseContentType: String, CaseIterable {
    case json = "JSON"
    case html = "HTML"
    case xml = "XML"
    case text = "Text"
    case css = "CSS"
    case javascript = "JavaScript"
    case image = "Image"

    var color: Color {
        switch self {
        case .json: return .purple
        case .html: return .orange
        case .xml: return .teal
        case .css: return .pink
        case .javascript: return .yellow
        case .text: return .gray
        case .image: return .green
        }
    }
}

// MARK: - JSON Formatted View

struct JSONFormattedView: View {
    let jsonString: String
    @State private var formattedJSON: String = ""
    @State private var parseError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let error = parseError {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Invalid JSON")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    Text(error)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            } else {
                JSONSyntaxHighlightedView(jsonString: formattedJSON)
            }
        }
        .onAppear {
            formatJSON()
        }
    }

    private func formatJSON() {
        guard let data = jsonString.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(
                  withJSONObject: jsonObject,
                  options: [.prettyPrinted, .sortedKeys]
              ),
              let prettyString = String(data: prettyData, encoding: .utf8) else {
            parseError = "Failed to parse JSON"
            return
        }
        formattedJSON = prettyString
    }
}

// MARK: - JSON Syntax Highlighted View

struct JSONSyntaxHighlightedView: View {
    let jsonString: String

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(jsonString.split(separator: "\n", omittingEmptySubsequences: false).enumerated()), id: \.offset) { index, line in
                    JSONLineView(line: String(line))
                }
            }
            .padding(12)
        }
    }
}

struct JSONLineView: View {
    let line: String

    var body: some View {
        highlightedContent
            .font(.system(size: 11, design: .monospaced))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var highlightedContent: some View {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            Text("")
        } else {
            // Simple JSON syntax highlighting
            let parts = parseJSONLine(trimmed)
            HStack(spacing: 0) {
                ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                    switch part.type {
                    case .key:
                        Text(part.content)
                            .foregroundStyle(.purple)
                    case .string:
                        Text(part.content)
                            .foregroundStyle(.green)
                    case .number:
                        Text(part.content)
                            .foregroundStyle(.cyan)
                    case .boolean:
                        Text(part.content)
                            .foregroundStyle(.yellow)
                    case .null:
                        Text(part.content)
                            .foregroundStyle(.gray)
                    case .punctuation:
                        Text(part.content)
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
    }

    private func parseJSONLine(_ line: String) -> [(content: String, type: JSONElementType)] {
        var parts: [(content: String, type: JSONElementType)] = []
        var current = ""
        var i = line.startIndex

        while i < line.endIndex {
            let char = line[i]

            // Key detection
            if char == "\"" {
                if !current.isEmpty {
                    parts.append((current, .punctuation))
                    current = ""
                }

                var keyContent = "\""
                i = line.index(after: i)
                while i < line.endIndex && line[i] != "\"" {
                    keyContent.append(line[i])
                    i = line.index(after: i)
                }
                if i < line.endIndex {
                    keyContent.append("\"")
                    i = line.index(after: i)
                }

                // Check if this is a key (followed by colon)
                let remaining = String(line[i...]).trimmingCharacters(in: .whitespaces)
                if remaining.hasPrefix(":") {
                    parts.append((keyContent, .key))
                } else {
                    parts.append((keyContent, .string))
                }
            }
            // String value detection (quote without colon before)
            else if char == "\"" {
                if !current.isEmpty {
                    parts.append((current, .punctuation))
                    current = ""
                }

                var stringContent = "\""
                i = line.index(after: i)
                while i < line.endIndex && line[i] != "\"" {
                    stringContent.append(line[i])
                    i = line.index(after: i)
                }
                if i < line.endIndex {
                    stringContent.append("\"")
                    i = line.index(after: i)
                }

                parts.append((stringContent, .string))
            }
            // Number detection
            else if char.isNumber || (char == "-" && current.isEmpty) {
                var numStr = current + String(char)
                i = line.index(after: i)
                while i < line.endIndex && (line[i].isNumber || line[i] == "." || line[i] == "e" || line[i] == "E" || line[i] == "-" || line[i] == "+") {
                    numStr.append(line[i])
                    i = line.index(after: i)
                }
                parts.append((numStr, .number))
                current = ""
                continue
            }
            // Boolean and null detection
            else if line[i...].hasPrefix("true") || line[i...].hasPrefix("false") || line[i...].hasPrefix("null") {
                if !current.isEmpty {
                    parts.append((current, .punctuation))
                    current = ""
                }

                if line[i...].hasPrefix("true") {
                    parts.append(("true", .boolean))
                    i = line.index(i, offsetBy: 4)
                } else if line[i...].hasPrefix("false") {
                    parts.append(("false", .boolean))
                    i = line.index(i, offsetBy: 5)
                } else {
                    parts.append(("null", .null))
                    i = line.index(i, offsetBy: 4)
                }
            }
            // Punctuation
            else if "{}[],:".contains(char) {
                if !current.isEmpty {
                    parts.append((current, .punctuation))
                    current = ""
                }
                parts.append((String(char), .punctuation))
                i = line.index(after: i)
            }
            // Whitespace and other
            else {
                current.append(char)
                i = line.index(after: i)
            }
        }

        if !current.isEmpty {
            parts.append((current, .punctuation))
        }

        return parts
    }
}

enum JSONElementType {
    case key      // Purple
    case string   // Green
    case number   // Cyan
    case boolean  // Yellow
    case null     // Gray
    case punctuation // Primary
}

// MARK: - HTML Formatted View

struct HTMLFormattedView: View {
    let htmlString: String

    var body: some View {
        HTMLSyntaxHighlightedView(htmlString: htmlString)
    }
}

struct HTMLSyntaxHighlightedView: View {
    let htmlString: String

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(htmlString.split(separator: "\n", omittingEmptySubsequences: false).enumerated()), id: \.offset) { index, line in
                    HTMLLineView(line: String(line))
                }
            }
            .padding(12)
        }
    }
}

struct HTMLLineView: View {
    let line: String

    var body: some View {
        highlightedContent
            .font(.system(size: 11, design: .monospaced))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var highlightedContent: some View {
        let parts = parseHTMLLine(line)
        HStack(spacing: 0) {
            ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                switch part.type {
                case .tag:
                    Text(part.content).foregroundStyle(.orange)
                case .attribute:
                    Text(part.content).foregroundStyle(.blue)
                case .value:
                    Text(part.content).foregroundStyle(.green)
                case .comment:
                    Text(part.content).foregroundStyle(.gray)
                case .text:
                    Text(part.content).foregroundStyle(.primary)
                }
            }
        }
    }

    private func parseHTMLLine(_ line: String) -> [(content: String, type: HTMLElementType)] {
        var parts: [(content: String, type: HTMLElementType)] = []
        var current = ""
        var i = line.startIndex

        while i < line.endIndex {
            let char = line[i]

            // Comment detection
            if line[i...].hasPrefix("<!--") {
                if !current.isEmpty {
                    parts.append((current, .text))
                    current = ""
                }

                var commentContent = ""
                while i < line.endIndex {
                    commentContent.append(line[i])
                    i = line.index(after: i)
                    if commentContent.hasSuffix("-->") {
                        break
                    }
                }
                parts.append((commentContent, .comment))
            }
            // Tag detection
            else if char == "<" {
                if !current.isEmpty {
                    parts.append((current, .text))
                    current = ""
                }

                var tagContent = "<"
                i = line.index(after: i)
                while i < line.endIndex && line[i] != ">" {
                    tagContent.append(line[i])
                    i = line.index(after: i)
                }
                if i < line.endIndex {
                    tagContent.append(">")
                    i = line.index(after: i)
                }

                parts.append((tagContent, .tag))
            }
            else {
                current.append(char)
                i = line.index(after: i)
            }
        }

        if !current.isEmpty {
            parts.append((current, .text))
        }

        return parts
    }
}

enum HTMLElementType {
    case tag        // Orange
    case attribute  // Blue
    case value      // Green
    case comment    // Gray
    case text       // Primary
}

// MARK: - XML Formatted View

struct XMLFormattedView: View {
    let xmlString: String
    @State private var formatted: String = ""

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(formatted.split(separator: "\n", omittingEmptySubsequences: false).enumerated()), id: \.offset) { _, line in
                    Text(String(line))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(12)
        }
        .onAppear {
            formatXML()
        }
    }

    private func formatXML() {
        let lines = xmlString.components(separatedBy: ">")
        var result = ""
        var indent = 0

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            if trimmed.hasPrefix("</") {
                indent = max(0, indent - 1)
            }

            result += String(repeating: "  ", count: indent) + "<" + trimmed + ">\n"

            if !trimmed.hasPrefix("</") && !trimmed.hasSuffix("/") {
                indent += 1
            }
        }

        formatted = result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Image Preview View

struct ImagePreviewView: View {
    let base64String: String
    @State private var uiImage: UIImage?
    @State private var imageLoadError: String?

    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            if let image = uiImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 400)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else if let error = imageLoadError {
                VStack(spacing: 6) {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.system(size: 24))
                        .foregroundStyle(.orange)
                    Text("Unable to load image")
                        .font(.system(size: 12, weight: .semibold))
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding()
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(12)
        .onAppear {
            loadImage()
        }
    }

    private func loadImage() {
        // Try base64 decoding
        if let data = Data(base64Encoded: base64String),
           let image = UIImage(data: data) {
            uiImage = image
            return
        }

        // Try data URL format (data:image/png;base64,...)
        if let dataUrlRange = base64String.range(of: "base64,") {
            let base64Data = base64String[dataUrlRange.upperBound...]
            if let data = Data(base64Encoded: String(base64Data)),
               let image = UIImage(data: data) {
                uiImage = image
                return
            }
        }

        imageLoadError = "Invalid base64 data or unsupported image format"
    }
}

// MARK: - Plain Text View

struct PlainTextView: View {
    let text: String
    let language: ResponseContentType

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(text.split(separator: "\n", omittingEmptySubsequences: false).enumerated()), id: \.offset) { index, line in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1)")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .frame(width: 40, alignment: .trailing)

                        Text(String(line))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(12)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        // JSON Preview
        ResponseFormatterView(
            responseBody: """
            {
              "users": [
                {
                  "id": 1,
                  "name": "John Doe",
                  "email": "john@example.com",
                  "active": true
                }
              ],
              "count": 1,
              "total": 10
            }
            """,
            contentType: .json
        )
        .frame(height: 200)
    }
    .padding()
}
