//
//  ReportScrubber.swift
//  diskindex
//
//  Namen, Pfade und Suchbegriffe werden vor dem Versand durch technische Profile ersetzt.
//

import Foundation

nonisolated enum ReportScrubber {
    static func text(_ input: String) -> String {
        var value = input
        value = replace(value, pattern: #"query=([^\n]+)"#) { queryProfile(String($0)) }
        value = replace(value, pattern: #"(?:/Volumes|/Users|~)[^\n\"']*"#) { pathProfile(String($0)) }
        value = replace(value, pattern: #""[^"\n]{1,240}""#) { nameProfile(String($0.dropFirst().dropLast())) }
        value = replace(value, pattern: #"'[^'\n]{1,240}'"#) { nameProfile(String($0.dropFirst().dropLast())) }
        return scrubRemainder(value)
    }

    private static func scrubRemainder(_ text: String) -> String {
        var result = ""
        var cursor = text.startIndex
        while let open = text[cursor...].firstIndex(of: "‹") {
            let head = String(text[cursor..<open])
            result += head.contains(where: { !isOrdinary($0) }) ? nameProfile(head) : head
            guard let close = text[open...].firstIndex(of: "›") else {
                result += String(text[open...])
                return result
            }
            result += text[open...close]
            cursor = text.index(after: close)
        }
        let tail = String(text[cursor...])
        result += tail.contains(where: { !isOrdinary($0) }) ? nameProfile(tail) : tail
        return result
    }

    static func leakCategory(in json: String, names: [String]) -> String? {
        if json.contains("/Volumes/") || json.contains("/Users/") || json.contains("~/") { return "path" }
        if json.contains(".localized") { return "localized" }
        for name in names {
            let folded = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard folded.count >= 3 else { continue }
            if json.contains(folded) || json.contains(folded.decomposedStringWithCanonicalMapping) { return "name" }
            if json.contains(folded.precomposedStringWithCanonicalMapping) { return "name" }
        }
        return nil
    }

    static func nameProfile(_ name: String) -> String {
        let ext = extensionLabel(name)
        let stem = stem(name)
        let flags = flags(in: stem.isEmpty ? name : stem)
        let scalars = unusualScalars(in: stem.isEmpty ? name : stem)
        let codes = scalars.isEmpty ? "" : " " + scalars.map { String(format: "U+%04X", $0) }.joined(separator: ",")
        return "‹name chars=\(stem.count) bytes=\(Data(stem.utf8).count) nf=\(normalization(stem)) ext=\(ext) flags=\(flags)\(codes)›"
    }

    private static func queryProfile(_ query: String) -> String {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        return "query=‹query chars=\(trimmed.count) flags=\(flags(in: trimmed))›"
    }

    private static func pathProfile(_ path: String) -> String {
        let depth = path.split(separator: "/").filter { !$0.isEmpty && $0 != "~" }.count
        return "‹path depth=\(max(depth, 1))›"
    }

    private static func extensionLabel(_ name: String) -> String {
        let base = name.trimmingCharacters(in: .whitespaces)
        guard let dot = base.lastIndex(of: "."), dot != base.startIndex else { return "‹odd›" }
        let ext = String(base[dot...])
        if ext.dropFirst().allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) {
            return ext.lowercased()
        }
        return "‹odd›"
    }

    private static func stem(_ name: String) -> String {
        let base = name.trimmingCharacters(in: .whitespaces)
        guard let dot = base.lastIndex(of: "."), dot != base.startIndex else { return base }
        let ext = String(base[dot...])
        guard ext.dropFirst().allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) else { return base }
        return String(base[..<dot])
    }

    private static func normalization(_ text: String) -> String {
        let nfc = text.precomposedStringWithCanonicalMapping
        let nfd = text.decomposedStringWithCanonicalMapping
        if text == nfc, text != nfd { return "NFC" }
        if text == nfd, text != nfc { return "NFD" }
        if text == nfc { return "NFC" }
        return "mixed"
    }

    private static func flags(in text: String) -> String {
        var flags: [String] = []
        if text.unicodeScalars.contains(where: { $0.properties.isEmoji && $0.value > 0x7F }) { flags.append("emoji") }
        if text.unicodeScalars.contains(where: { $0.properties.isBidiControl || ($0.value >= 0x0590 && $0.value <= 0x08FF) }) {
            flags.append("rtl")
        }
        if text.unicodeScalars.contains(where: { $0.properties.isGraphemeExtend }) { flags.append("combining") }
        if text.unicodeScalars.contains(where: { $0.value < 0x20 && $0.value != 0x09 }) { flags.append("control") }
        if text.hasSuffix(" ") { flags.append("trailing-space") }
        if text.hasPrefix(".") { flags.append("leading-dot") }
        if !text.utf8.allSatisfy({ $0 != 0 }) { flags.append("invalid-utf8") }
        return flags.isEmpty ? "none" : flags.joined(separator: ",")
    }

    private static func unusualScalars(in text: String) -> [UInt32] {
        var seen: [UInt32] = []
        for scalar in text.unicodeScalars where !isOrdinary(Character(scalar)) && !scalar.properties.isGraphemeExtend {
            if !seen.contains(scalar.value) { seen.append(scalar.value) }
            if seen.count == 5 { break }
        }
        return seen
    }

    private static func isOrdinary(_ text: String) -> Bool {
        text.allSatisfy { isOrdinary($0) }
    }

    private static func isOrdinary(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy { scalar in
            let value = scalar.value
            if value < 0x80, scalar.properties.isAlphabetic || scalar.properties.numericType != nil { return true }
            let allowed: Set<UInt32> = [
                0x20, 0x09, 0x2D, 0x5F, 0x2E, 0x2C, 0x3A, 0x3B, 0x28, 0x29, 0x5B, 0x5D,
                0x3D, 0x2F, 0x7B, 0x7D, 0x3C, 0x3E, 0x27, 0x22, 0x60, 0x7E, 0x21, 0x3F,
                0x2B, 0x2A, 0x23, 0x25, 0x26, 0x40, 0x7C, 0x5C,
            ]
            return allowed.contains(value)
        }
    }

    private static func replace(_ text: String, pattern: String, _ map: (Substring) -> String) -> String {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        var result = ""
        var cursor = text.startIndex
        for match in expression.matches(in: text, range: range) {
            guard let whole = Range(match.range, in: text) else { continue }
            let captured = match.numberOfRanges > 1 ? Range(match.range(at: 1), in: text) : whole
            result += text[cursor..<whole.lowerBound]
            result += map(text[captured ?? whole])
            cursor = whole.upperBound
        }
        result += text[cursor...]
        return result
    }
}
