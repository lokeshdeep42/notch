import Foundation
import Services

/// Clipboard history on disk: a JSON manifest plus image blobs, in a folder that is private to the
/// user (0700), excluded from Time Machine and from Spotlight. Newest entries first.
final class ClipboardStore {
    let root: URL
    private(set) var entries: [ClipEntry] = []
    var maxItems: Int
    var maxBytes: Int64

    private var manifestURL: URL { root.appendingPathComponent("history.json") }

    init(root: URL, maxItems: Int = 200, maxBytes: Int64 = 200_000_000) {
        self.root = root
        self.maxItems = maxItems
        self.maxBytes = maxBytes
        prepareDirectory()
        load()
        prune()
    }

    func blobURL(_ fileName: String) -> URL {
        root.appendingPathComponent(fileName)
    }

    /// Adds an entry. If it repeats the newest entry's content, the old one just moves to the top.
    func add(_ entry: ClipEntry, imageData: Data? = nil, thumbnailData: Data? = nil) {
        if let index = entries.firstIndex(where: { $0.hasSameContent(as: entry) }) {
            var existing = entries.remove(at: index)
            existing.createdAt = entry.createdAt
            existing.sourceAppName = entry.sourceAppName ?? existing.sourceAppName
            existing.sourceBundleID = entry.sourceBundleID ?? existing.sourceBundleID
            entries.insert(existing, at: 0)
            save()
            return
        }

        var stored = entry
        if let imageData {
            let name = "\(entry.id.uuidString).png"
            if (try? imageData.write(to: blobURL(name), options: .atomic)) != nil {
                stored.imageFileName = name
            }
        }
        if let thumbnailData {
            let name = "\(entry.id.uuidString)-thumb.png"
            if (try? thumbnailData.write(to: blobURL(name), options: .atomic)) != nil {
                stored.thumbnailFileName = name
            }
        }
        entries.insert(stored, at: 0)
        prune()
        save()
    }

    func remove(ids: Set<UUID>) {
        for entry in entries where ids.contains(entry.id) {
            deleteBlobs(of: entry)
        }
        entries.removeAll { ids.contains($0.id) }
        save()
    }

    func removeAll() {
        entries.forEach(deleteBlobs)
        entries.removeAll()
        save()
    }

    /// Enforces caps, oldest first.
    func prune() {
        var total = entries.reduce(Int64(0)) { $0 + $1.byteSize }
        while entries.count > maxItems || (total > maxBytes && entries.count > 1) {
            let victim = entries.removeLast()
            total -= victim.byteSize
            deleteBlobs(of: victim)
        }
    }

    // MARK: Persistence

    func save() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(entries).write(to: manifestURL, options: .atomic)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: manifestURL.path)
        } catch {
            Log.clipboard.error("Failed to save history: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: manifestURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        entries = (try? decoder.decode([ClipEntry].self, from: data)) ?? []
    }

    private func deleteBlobs(of entry: ClipEntry) {
        for name in [entry.imageFileName, entry.thumbnailFileName].compactMap({ $0 }) {
            try? FileManager.default.removeItem(at: blobURL(name))
        }
    }

    private func prepareDirectory() {
        let fm = FileManager.default
        try? fm.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try? fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path)
        var url = root
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
        // Spotlight skips folders containing this marker.
        let marker = root.appendingPathComponent(".metadata_never_index")
        if !fm.fileExists(atPath: marker.path) {
            fm.createFile(atPath: marker.path, contents: Data())
        }
    }
}
