import Foundation
import SwiftUI

/// CSS 스타일 문자열을 파싱하여 SwiftUI 속성으로 변환
struct CSSParser {
    
    /// 파싱된 CSS 스타일 속성
    struct StyleProperties {
        var color: Color?
        var backgroundColor: Color?
        var fontSize: CGFloat?
        var fontWeight: Font.Weight?
        var fontStyle: Font.Design?
        var isBold: Bool = false
        var isItalic: Bool = false
        var padding: EdgeInsets?
        var opacity: Double = 1.0
        
        /// SwiftUI Font 생성
        var font: Font? {
            let size = fontSize ?? 14
            var weight = fontWeight ?? .regular

            if isBold {
                weight = .bold
            }

            var font = Font.system(size: size, weight: weight)

            // Apply font design (monospaced)
            if fontStyle == .monospaced {
                font = Font.system(size: size, design: .monospaced).weight(weight)
            }

            return font
        }
    }
    
    /// CSS 문자열을 파싱하여 스타일 속성 추출
    /// - Parameter cssString: CSS 형식의 스타일 문자열 (예: "color: red; font-size: 14px;")
    /// - Returns: 파싱된 스타일 속성
    static func parse(_ cssString: String) -> StyleProperties {
        var styles = StyleProperties()
        
        // 세미콜론으로 분리된 각 CSS 속성 처리
        let properties = cssString.components(separatedBy: ";")
        
        for property in properties {
            let trimmed = property.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            
            let parts = trimmed.components(separatedBy: ":")
            guard parts.count >= 2 else { continue }
            
            let key = parts[0].trimmingCharacters(in: .whitespaces).lowercased()
            let value = parts[1...].joined(separator: ":").trimmingCharacters(in: .whitespaces).lowercased()
            
            parseProperty(key: key, value: value, styles: &styles)
        }
        
        return styles
    }
    
    /// 개별 CSS 속성 파싱
    private static func parseProperty(key: String, value: String, styles: inout StyleProperties) {
        switch key {
        case "color", "foreground", "text-color":
            styles.color = parseColor(value)
            
        case "background-color", "background":
            styles.backgroundColor = parseColor(value)
            
        case "font-size":
            styles.fontSize = parseFontSize(value)
            
        case "font-weight":
            styles.fontWeight = parseFontWeight(value)
            if styles.fontWeight == .bold || styles.fontWeight == .heavy {
                styles.isBold = true
            }
            
        case "font-style":
            if value.contains("italic") {
                styles.isItalic = true
                styles.fontStyle = .default
            }
            
        case "font-family":
            // SwiftUI에서는 시스템 폰트 사용 (커스텀 폰트 제한)
            if value.contains("mono") {
                styles.fontStyle = .monospaced
            } else if value.contains("serif") {
                styles.fontStyle = .default
            }
            
        case "font":
            // 단축 속성: "bold 14px Arial" 형식
            parseFontShorthand(value, styles: &styles)
            
        case "opacity":
            if value.contains("%") {
                if let opacity = Double(value.replacingOccurrences(of: "%", with: "")) {
                    styles.opacity = opacity / 100.0
                }
            } else if let opacity = Double(value) {
                styles.opacity = opacity
            }
            
        case "padding":
            styles.padding = parsePadding(value)

        case "font-thickness":
            // Bold 감지
            if value.contains("bold") || value.contains("700") || value.contains("900") {
                styles.isBold = true
            }
            
        default:
            break
        }
    }
    
    /// 색상 문자열 파싱 (hex, rgb, named colors)
    private static func parseColor(_ value: String) -> Color? {
        let value = value.trimmingCharacters(in: .whitespaces)
        
        // #RGB 또는 #RRGGBB 형식
        if value.hasPrefix("#") {
            return parseHexColor(value)
        }
        
        // rgb(r, g, b) 또는 rgba(r, g, b, a) 형식
        if value.hasPrefix("rgb") {
            return parseRgbColor(value)
        }
        
        // Named colors
        return parseNamedColor(value)
    }
    
    /// Hex 색상 파싱
    private static func parseHexColor(_ hex: String) -> Color? {
        var hexString = hex.dropFirst() // # 제거

        // 3자리 hex를 6자리로 확장 (#F00 -> #FF0000)
        if hexString.count == 3 {
            hexString = Substring(hexString.map { String($0) + String($0) }.joined())
        }

        guard hexString.count == 6 else { return nil }

        guard let rgb = UInt32(String(hexString), radix: 16) else { return nil }
        
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        
        return Color(red: r, green: g, blue: b)
    }
    
    /// RGB 색상 파싱
    private static func parseRgbColor(_ value: String) -> Color? {
        // rgb(255, 0, 0) 또는 rgba(255, 0, 0, 1)에서 숫자만 추출
        let pattern = "\\d+\\.?\\d*"
        let regex = try? NSRegularExpression(pattern: pattern)
        
        let nsValue = value as NSString
        let range = NSRange(location: 0, length: nsValue.length)
        let matches = regex?.matches(in: value, range: range) ?? []
        
        guard matches.count >= 3 else { return nil }
        
        let numbers = matches.compactMap { match -> Double? in
            Double(nsValue.substring(with: match.range))
        }
        
        guard numbers.count >= 3 else { return nil }
        
        let r = numbers[0] / 255.0
        let g = numbers[1] / 255.0
        let b = numbers[2] / 255.0
        let a = numbers.count > 3 ? numbers[3] : 1.0
        
        return Color(red: r, green: g, blue: b, opacity: a)
    }
    
    /// Named 색상 파싱
    private static func parseNamedColor(_ name: String) -> Color? {
        let name = name.lowercased().trimmingCharacters(in: .whitespaces)
        
        // 기본 웹 색상
        let namedColors: [String: Color] = [
            "red": .red,
            "blue": .blue,
            "green": .green,
            "yellow": .yellow,
            "orange": .orange,
            "purple": .purple,
            "pink": .pink,
            "cyan": .cyan,
            "gray": .gray,
            "grey": .gray,
            "black": Color(white: 0),
            "white": Color(white: 1),
            "clear": .clear,
            "transparent": .clear,
            
            // 추가 웹 색상
            "lightred": Color(red: 1, green: 0.7, blue: 0.7),
            "darkred": Color(red: 0.5, green: 0, blue: 0),
            "lime": Color(red: 0, green: 1, blue: 0),
            "navy": Color(red: 0, green: 0, blue: 0.5),
            "teal": Color(red: 0, green: 0.5, blue: 0.5),
            "olive": Color(red: 0.5, green: 0.5, blue: 0),
            "maroon": Color(red: 0.5, green: 0, blue: 0),
            "aqua": .cyan,
            "silver": Color(white: 0.75),
            "fuchsia": Color(red: 1, green: 0, blue: 1),
        ]
        
        return namedColors[name]
    }
    
    /// 폰트 크기 파싱
    private static func parseFontSize(_ value: String) -> CGFloat? {
        let cleanValue = value
            .replacingOccurrences(of: "px", with: "")
            .replacingOccurrences(of: "em", with: "")
            .replacingOccurrences(of: "rem", with: "")
            .trimmingCharacters(in: .whitespaces)
        
        return CGFloat(Double(cleanValue) ?? 14.0)
    }
    
    /// 폰트 두께 파싱
    private static func parseFontWeight(_ value: String) -> Font.Weight? {
        let value = value.lowercased()
        
        if value.contains("100") { return .thin }
        if value.contains("200") { return .thin }
        if value.contains("300") { return .light }
        if value.contains("400") || value.contains("normal") { return .regular }
        if value.contains("500") || value.contains("medium") { return .semibold }
        if value.contains("600") { return .semibold }
        if value.contains("700") || value.contains("bold") { return .bold }
        if value.contains("800") { return .heavy }
        if value.contains("900") { return .heavy }
        
        return nil
    }
    
    /// 폰트 단축 속성 파싱 (예: "bold 14px Arial")
    private static func parseFontShorthand(_ value: String, styles: inout StyleProperties) {
        let parts = value.components(separatedBy: " ")
        
        for part in parts {
            // bold, italic 등의 키워드 감지
            if part.contains("bold") {
                styles.isBold = true
                styles.fontWeight = .bold
            } else if part.contains("italic") {
                styles.isItalic = true
            } else if part.contains("px") || part.contains("em") {
                // 크기 감지
                styles.fontSize = parseFontSize(part)
            }
        }
    }
    
    /// Padding 파싱
    private static func parsePadding(_ value: String) -> EdgeInsets? {
        let values = value.components(separatedBy: " ")
            .map { $0.replacingOccurrences(of: "px", with: "").trimmingCharacters(in: .whitespaces) }
            .compactMap { Double($0) }
        
        guard !values.isEmpty else { return nil }
        
        if values.count == 1 {
            let p = CGFloat(values[0])
            return EdgeInsets(top: p, leading: p, bottom: p, trailing: p)
        } else if values.count == 2 {
            let vertical = CGFloat(values[0])
            let horizontal = CGFloat(values[1])
            return EdgeInsets(top: vertical, leading: horizontal, bottom: vertical, trailing: horizontal)
        } else if values.count >= 4 {
            return EdgeInsets(
                top: CGFloat(values[0]),
                leading: CGFloat(values[3]),
                bottom: CGFloat(values[2]),
                trailing: CGFloat(values[1])
            )
        }
        
        return nil
    }
}
