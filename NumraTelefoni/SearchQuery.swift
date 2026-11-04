import Foundation

struct AppError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

struct SearchQuery {
    let sql: String
    let arguments: [String]

    static func normalize(_ value: String) -> String {
        let upper = value.uppercased(with: Locale(identifier: "en_US_POSIX"))
        return upper.decomposedStringWithCanonicalMapping.unicodeScalars
            .filter { !CharacterSet.nonBaseCharacters.contains($0) }
            .map(String.init).joined()
    }

    private static func matches(_ value: String, _ pattern: String) -> Bool {
        value.range(of: pattern, options: .regularExpression) != nil
    }

    private static func escapedLike(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
    }

    private static func term(_ column: String, _ value: String, _ args: inout [String]) throws -> String {
        guard !value.replacingOccurrences(of: "*", with: "").isEmpty else {
            throw AppError(message: "Shkruaj të paktën një shkronjë krahas *.")
        }
        if !value.contains("*") {
            args.append(value)
            return "\(column) = ?"
        }
        if value.hasSuffix("*"), value.filter({ $0 == "*" }).count == 1 {
            let prefix = String(value.dropLast())
            args += [prefix, prefix + "\u{FFFF}"]
            return "(\(column) >= ? AND \(column) < ?)"
        }
        args.append(escapedLike(value).replacingOccurrences(of: "*", with: "%"))
        return "\(column) LIKE ? ESCAPE '\\'"
    }

    static func build(_ input: String) throws -> SearchQuery {
        var q = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { throw AppError(message: "Shkruaj emrin ose numrin e telefonit.") }
        guard q.utf16.count <= 160 else { throw AppError(message: "Kërkimi është shumë i gjatë.") }
        var arguments: [String] = []
        var conditions = ""
        let digits = q.replacingOccurrences(of: "[\\s()+.\\-]", with: "", options: .regularExpression)
        if matches(digits, "^[0-9]+$") {
            guard digits.count >= 4 else { throw AppError(message: "Shkruaj të paktën 4 shifra.") }
            var prefixes = [digits]
            var local = digits
            if local.hasPrefix("00355") { local = String(local.dropFirst(5)) }
            else if local.hasPrefix("355") { local = String(local.dropFirst(3)) }
            if local.hasPrefix("0") { local = String(local.dropFirst()) }
            if local.hasPrefix("6"), local.count >= 4 {
                for p in [local, "0" + local, "355" + local, "+355" + local, "00355" + local] {
                    if !prefixes.contains(p) { prefixes.append(p) }
                }
            }
            conditions = "(" + prefixes.map { prefix in
                arguments += [prefix, prefix + "\u{FFFF}"]
                return "(phone >= ? AND phone < ?)"
            }.joined(separator: " OR ") + ")"
        } else {
            var father: String?
            if let slash = q.firstIndex(of: "/") {
                father = normalize(String(q[q.index(after: slash)...]).trimmingCharacters(in: .whitespacesAndNewlines))
                q = String(q[..<slash]).trimmingCharacters(in: .whitespacesAndNewlines)
                guard let f = father, !f.isEmpty, !f.contains("/") else {
                    throw AppError(message: "Pas / shkruaj atësinë.")
                }
            }
            guard !q.isEmpty else { throw AppError(message: "Shkruaj emrin dhe mbiemrin përpara /.") }
            let words = normalize(q).split(whereSeparator: { $0.isWhitespace }).map(String.init)
            switch words.count {
            case 1:
                conditions = try term("n_surname", words[0], &arguments)
            case 2, 3:
                conditions = try term("n_surname", words[words.count - 1], &arguments)
                conditions += " AND " + (try term("n_name", words[0], &arguments))
                if words.count == 3 {
                    guard father == nil else { throw AppError(message: "Përdor një format të vetëm për atësinë.") }
                    father = words[1]
                }
            default:
                throw AppError(message: "Përdor: Emër Mbiemër ose Emër Atësi Mbiemër.")
            }
            if let father = father {
                let f = father.replacingOccurrences(of: "*", with: "")
                guard !f.isEmpty else { throw AppError(message: "Shkruaj atësinë pas /.") }
                conditions += " AND (n_father LIKE ? ESCAPE '\\' OR (length(n_father) >= 2 AND substr(?,1,length(n_father)) = n_father))"
                arguments += [escapedLike(f) + "%", f]
            }
        }
        return SearchQuery(sql: "SELECT name,surname,father,phone FROM p WHERE " + conditions + " LIMIT 501", arguments: arguments)
    }
}
