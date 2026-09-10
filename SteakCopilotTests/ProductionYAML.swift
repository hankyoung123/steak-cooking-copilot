import Foundation

/// Reads `Config/production.yaml` with enough structure for tests to assert on
/// *keys* rather than free text.
///
/// The configuration file documents the correctness rules in comments (for
/// example it explains that there is deliberately no per-cut target
/// temperature). A naive substring check over the whole file therefore reports
/// a false positive on the documentation itself. These helpers strip comments
/// first, so a test can ask what is actually *configured*.
enum ProductionYAML {
    static var url: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Config/production.yaml")
    }

    static func text() throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }

    /// Every uncommented line, i.e. what the generator actually reads.
    static func contentLines() throws -> [String] {
        try text()
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .map(strippingComment)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    /// All configured keys, in file order.
    static func keys() throws -> [String] {
        try contentLines().compactMap { line in
            guard let range = line.range(of: ":") else { return nil }
            let name = line[line.startIndex..<range.lowerBound]
                .trimmingCharacters(in: .whitespaces)
            // Reject list items and quoted values.
            guard let first = name.first, first.isLetter || first == "_" else {
                return nil
            }
            return name
        }
    }

    /// True when the key is configured (not merely mentioned in a comment).
    static func hasKey(_ key: String) throws -> Bool {
        try keys().contains(key)
    }

    /// How many times the key is configured. Used to prove a value exists in
    /// exactly one place.
    static func count(ofKey key: String) throws -> Int {
        try keys().filter { $0 == key }.count
    }

    /// Keys configured inside a top-level section (until the next line with
    /// zero indentation), so a check can be scoped to one part of the file.
    static func section(_ name: String) throws -> [String] {
        var keys: [String] = []
        var inside = false
        var sawSection = false

        for rawLine in try text().split(separator: "\n", omittingEmptySubsequences: false) {
            let line = strippingComment(String(rawLine))
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            let indent = line.prefix { $0 == " " }.count
            if indent == 0 {
                if inside { break }
                if trimmed.hasPrefix("\(name):") {
                    inside = true
                    sawSection = true
                }
                continue
            }
            guard inside, let range = line.range(of: ":") else { continue }
            let key = line[line.startIndex..<range.lowerBound]
                .trimmingCharacters(in: .whitespaces)
            guard let first = key.first, first.isLetter || first == "_" else {
                continue
            }
            keys.append(key)
        }

        _ = sawSection
        return keys
    }

    /// Keys configured at any depth whose name matches the predicate.
    static func keys(matching predicate: (String) -> Bool) throws -> [String] {
        try keys().filter(predicate)
    }

    /// Removes a trailing `#` comment, respecting simple quoting.
    private static func strippingComment(_ line: String) -> String {
        var result = ""
        var quote: Character?
        for character in line {
            if let current = quote {
                result.append(character)
                if character == current { quote = nil }
                continue
            }
            if character == "\"" || character == "'" {
                quote = character
                result.append(character)
                continue
            }
            if character == "#" { break }
            result.append(character)
        }
        return result
    }
}
