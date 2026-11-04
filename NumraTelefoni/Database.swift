import Foundation
import SQLite3

struct Person: Identifiable {
    let id = UUID()
    let name: String
    let surname: String
    let father: String
    let phone: String
}

final class PhoneDatabase {
    private var handle: OpaquePointer?
    init(url: URL) throws {
        guard sqlite3_open_v2(url.path, &handle, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK else {
            if let handle = handle { sqlite3_close(handle) }
            handle = nil
            throw AppError(message: "Baza nuk mund të hapet. Zgjidh skedarin allphone.db ose allphone_perditesuar.db.")
        }
        sqlite3_busy_timeout(handle, 3000)
    }
    deinit { sqlite3_close(handle) }

    func rows(_ sql: String, arguments: [String] = []) throws -> [[String]] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK, let prepared = statement else {
            throw AppError(message: "Struktura e bazës nuk përputhet me aplikacionin.")
        }
        defer { sqlite3_finalize(prepared) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for (index, value) in arguments.enumerated() {
            let result = value.withCString { sqlite3_bind_text(prepared, Int32(index + 1), $0, -1, transient) }
            guard result == SQLITE_OK else { throw AppError(message: "Kërkimi nuk mund të përgatitet.") }
        }
        var result: [[String]] = []
        while true {
            let status = sqlite3_step(prepared)
            if status == SQLITE_DONE { return result }
            guard status == SQLITE_ROW else { throw AppError(message: "Gabim gjatë leximit të bazës. Provo ta importosh sërish.") }
            var row: [String] = []
            for i in 0..<sqlite3_column_count(prepared) {
                if let bytes = sqlite3_column_text(prepared, i) { row.append(String(cString: bytes)) }
                else { row.append("") }
            }
            result.append(row)
        }
    }

    func validate() throws {
        let columns = Set(try rows("PRAGMA table_info(p)").map { $0[1] })
        let required: Set<String> = ["name","surname","father","phone","n_name","n_surname","n_father"]
        guard required.isSubset(of: columns) else { throw AppError(message: "Skedari nuk ka strukturën e bazës së numrave.") }
        _ = try rows("SELECT name,surname,father,phone,n_name,n_surname,n_father FROM p LIMIT 1")
        var names = false
        var phones = false
        for index in try rows("PRAGMA index_list(p)") {
            let safe = index[1].replacingOccurrences(of: "'", with: "''")
            let cols = try rows("PRAGMA index_info('\(safe)')").map { $0[2] }
            if cols.count >= 2, cols[0] == "n_surname", cols[1] == "n_name" { names = true }
            if cols.first == "phone" { phones = true }
        }
        guard names && phones else { throw AppError(message: "Mungojnë indekset e kërkimit. Importo bazën e krijuar në kompjuter.") }
    }

    func search(_ query: SearchQuery) throws -> [Person] {
        try rows(query.sql, arguments: query.arguments).map {
            Person(name: $0[0], surname: $0[1], father: $0[2], phone: $0[3])
        }
    }
}
