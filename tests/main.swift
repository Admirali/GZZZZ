import Foundation
import SQLite3

let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: directory) }
let file = directory.appendingPathComponent("test.db")
var writable: OpaquePointer?
precondition(sqlite3_open(file.path, &writable) == SQLITE_OK)
let ddl = """
CREATE TABLE p (name TEXT,surname TEXT,father TEXT,phone TEXT,n_name TEXT,n_surname TEXT,n_father TEXT);
CREATE INDEX ix_ns ON p(n_surname,n_name);
CREATE INDEX ix_ph ON p(phone);
"""
precondition(sqlite3_exec(writable, ddl, nil, nil, nil) == SQLITE_OK)
let fixtures = [
    ["Arbën","Çela","BESNIK","690000001","ARBEN","CELA","BESNIK"],
    ["Arbena","Çela","BE","0690000002","ARBENA","CELA","BE"],
    ["Bora","Prova","ILIR","355690000003","BORA","PROVA","ILIR"],
    ["Drita","Prova","ILIR","+355690000004","DRITA","PROVA","ILIR"],
    ["Elira","Prova","ILIR","00355690000005","ELIRA","PROVA","ILIR"],
    ["X","P%Q","ILIR","0000","X","P%Q","ILIR"],
    ["X","P_Q","ILIR","0001","X","P_Q","ILIR"],
    ["X","O'NEIL","ILIR","0002","X","O'NEIL","ILIR"]
]
func insert(_ row: [String]) {
    var prepared: OpaquePointer?
    precondition(sqlite3_prepare_v2(writable,"INSERT INTO p VALUES (?,?,?,?,?,?,?)",-1,&prepared,nil) == SQLITE_OK)
    defer { sqlite3_finalize(prepared) }
    let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    for (i,value) in row.enumerated() {
        let code = value.withCString { sqlite3_bind_text(prepared,Int32(i+1),$0,-1,transient) }
        precondition(code == SQLITE_OK)
    }
    precondition(sqlite3_step(prepared) == SQLITE_DONE)
}
for row in fixtures { insert(row) }
for i in 0..<510 { insert(["Demo","Limit","",String(i),"DEMO","LIMIT",""]) }
sqlite3_close(writable)
writable = nil
let db = try PhoneDatabase(url: file)
try db.validate()
let cases: [(String,[String])] = [
    ("arben cela",["Arbën"]),("ARBËN ÇELA",["Arbën"]),
    ("Cela",["Arbën","Arbena"]),("Ar* Ce*",["Arbën","Arbena"]),
    ("Arben Besnik Cela",["Arbën"]),("Ar* Cela /Besnik",["Arbën","Arbena"]),
    ("Arben Cela /Ilir",[]),("690000001",["Arbën"]),
    ("+355 69 000 0001",["Arbën"]),("0690000001",["Arbën"]),
    ("00355690000001",["Arbën"]),("69000000",["Arbën","Arbena","Bora","Drita","Elira"]),
    ("69 000-0002",["Arbena"]),("355690000003",["Bora"]),
    ("690000004",["Drita"]),("690000005",["Elira"]),
    ("Ar*en Cela",["Arbën"]),("P%*",["X"]),("P_*",["X"]),
    ("O'Neil",["X"]),("X' OR",[]),("Nuk Ekziston",[])
]
for (input,expected) in cases {
    let query = try SearchQuery.build(input)
    let actual = try db.search(query).map { $0.name }.sorted()
    precondition(actual == expected.sorted(), "Failed query: \(input)")
    if input == "arben cela" || input == "690000001" {
        let plan = try db.rows("EXPLAIN QUERY PLAN " + query.sql, arguments: query.arguments)
        precondition(plan.flatMap { $0 }.joined().contains("INDEX"))
    }
}
for input in ["","123","*","Arben Cela /","/Besnik","Arben Cela /*","A B C D",String(repeating:"a",count:161),"X' OR 1=1 --"] {
    var rejected = false
    do { _ = try SearchQuery.build(input) } catch { rejected = true }
    precondition(rejected, "Expected rejection")
}
let limited = try db.search(SearchQuery.build("Demo Limit"))
precondition(limited.count == 501)
print("PASS: 32 search / validation / limit scenarios; name and phone indexes verified.")
