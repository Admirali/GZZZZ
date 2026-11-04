import Foundation
import Combine

/// Published state is updated on the main queue; database and file work use one serial worker.
final class PhoneStore: ObservableObject {
    @Published private(set) var ready = false
    @Published private(set) var busy = false
    @Published private(set) var progress: Double?
    @Published private(set) var status = "Importo bazën për të filluar."
    @Published private(set) var results: [Person] = []
    private let worker = DispatchQueue(label: "al.lokal.numratelefoni.database", qos: .userInitiated)
    private let directory: URL
    private let databaseURL: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        directory = base.appendingPathComponent("PhoneData", isDirectory: true)
        databaseURL = directory.appendingPathComponent("allphone.db")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            var excluded = directory
            var attributes = URLResourceValues()
            attributes.isExcludedFromBackup = true
            try excluded.setResourceValues(attributes)
            ready = FileManager.default.fileExists(atPath: databaseURL.path)
            if ready { status = "Baza është gati. Shkruaj kërkimin." }
        } catch { status = "Nuk mund të krijohet hapësira për bazën. Kontrollo hapësirën në iPhone." }
    }

    func report(_ message: String) { status = message }

    func search(_ text: String) {
        guard ready, !busy else { return }
        let query: SearchQuery
        do { query = try SearchQuery.build(text) }
        catch { results = []; status = error.localizedDescription; return }
        busy = true
        progress = nil
        status = "Po kërkohet…"
        let url = databaseURL
        worker.async {
            do {
                let found = try PhoneDatabase(url: url).search(query)
                let overflow = found.count > 500
                DispatchQueue.main.async {
                    self.results = Array(found.prefix(500))
                    self.busy = false
                    self.status = found.isEmpty ? "Asnjë rezultat. Provo një shkrim tjetër ose përdor *."
                        : overflow ? "Mbi 500 rezultate. Shfaqen 500 të parat; ngushto kërkimin."
                        : "\(found.count) " + (found.count == 1 ? "rezultat" : "rezultate")
                }
            } catch {
                let message = error.localizedDescription
                DispatchQueue.main.async { self.busy = false; self.results = []; self.status = message }
            }
        }
    }

    func importDatabase(from pickedURL: URL) {
        guard !busy else { return }
        busy = true
        progress = nil
        status = "Po përgatitet importimi. Mbaje aplikacionin hapur…"
        let access = pickedURL.startAccessingSecurityScopedResource()
        let destination = databaseURL
        let staging = directory.appendingPathComponent("allphone.incoming")
        worker.async {
            defer { if access { pickedURL.stopAccessingSecurityScopedResource() } }
            do {
                let coordinator = NSFileCoordinator()
                var coordinationError: NSError?
                var copyError: Error?
                coordinator.coordinate(readingItemAt: pickedURL, options: .withoutChanges, error: &coordinationError) { source in
                    do {
                        try Self.copy(source, to: staging) { copied, total in
                            DispatchQueue.main.async {
                                self.progress = total > 0 ? min(0.99, Double(copied) / Double(total)) : nil
                                self.status = "Po importohet: \(copied / (1024 * 1024)) MB. Mbaje aplikacionin hapur…"
                            }
                        }
                    } catch { copyError = error }
                }
                if let error = coordinationError { throw error }
                if let error = copyError { throw error }
                DispatchQueue.main.async { self.progress = nil; self.status = "Po kontrollohet baza…" }
                try Self.validateFile(staging)
                if FileManager.default.fileExists(atPath: destination.path) {
                    _ = try FileManager.default.replaceItemAt(destination, withItemAt: staging)
                } else { try FileManager.default.moveItem(at: staging, to: destination) }
                DispatchQueue.main.async {
                    self.ready = true; self.busy = false; self.progress = nil; self.results = []
                    self.status = "Importimi përfundoi. Mund të kërkosh pa internet."
                }
            } catch {
                try? FileManager.default.removeItem(at: staging)
                let message = (error as? AppError)?.message
                    ?? "Importimi dështoi. Kontrollo që skedari është shkarkuar në Files dhe që ka hapësirë të lirë, pastaj provo sërish."
                DispatchQueue.main.async { self.busy = false; self.progress = nil; self.status = message }
            }
        }
    }

    private static func validateFile(_ url: URL) throws {
        // Separate scope ensures SQLite closes before the staged file is renamed.
        let db = try PhoneDatabase(url: url)
        try db.validate()
    }

    private static func copy(_ source: URL, to destination: URL, progress: (Int64, Int64) -> Void) throws {
        let fm = FileManager.default
        let size = Int64((try source.resourceValues(forKeys: [.fileSizeKey])).fileSize ?? -1)
        let free = (try fm.attributesOfFileSystem(forPath: destination.deletingLastPathComponent().path)[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
        guard size < 0 || free >= size + 64 * 1024 * 1024 else {
            throw AppError(message: "Nuk ka hapësirë të mjaftueshme. Liro të paktën 1.2 GB dhe provo sërish.")
        }
        if fm.fileExists(atPath: destination.path) { try fm.removeItem(at: destination) }
        guard fm.createFile(atPath: destination.path, contents: nil, attributes: [.protectionKey: FileProtectionType.complete]) else {
            throw AppError(message: "Nuk mund të krijohet kopja e bazës. Kontrollo hapësirën e lirë.")
        }
        let input = try FileHandle(forReadingFrom: source)
        defer { try? input.close() }
        let output = try FileHandle(forWritingTo: destination)
        defer { try? output.close() }
        var copied: Int64 = 0
        var lastUpdate = Date.distantPast
        while true {
            let count = try autoreleasepool { () throws -> Int in
                guard let block = try input.read(upToCount: 1024 * 1024), !block.isEmpty else { return 0 }
                try output.write(contentsOf: block)
                return block.count
            }
            if count == 0 { break }
            copied += Int64(count)
            if Date().timeIntervalSince(lastUpdate) > 0.25 {
                progress(copied, size)
                lastUpdate = Date()
            }
        }
        try output.synchronize()
        guard size < 0 || copied == size else { throw AppError(message: "Skedari nuk u kopjua plotësisht. Provo përsëri.") }
    }
}
