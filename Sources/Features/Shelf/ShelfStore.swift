import Foundation
import Services

/// On-disk shelf: one folder per item plus a JSON manifest. Newest items first.
///
/// The static `copyIn`/`write` functions touch only the file system and are safe to call off the
/// main actor; everything that mutates `items` runs on the caller's (main) actor.
final class ShelfStore {
    let root: URL
    private(set) var items: [ShelfItem] = []

    private var manifestURL: URL { root.appendingPathComponent("manifest.json") }

    init(root: URL) {
        self.root = root
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        load()
    }

    func url(for item: ShelfItem) -> URL {
        Self.url(for: item, root: root)
    }

    static func url(for item: ShelfItem, root: URL) -> URL {
        root.appendingPathComponent(item.id.uuidString, isDirectory: true)
            .appendingPathComponent(item.fileName)
    }

    var totalBytes: Int64 { items.reduce(0) { $0 + $1.byteSize } }

    // MARK: File operations (callable off the main actor)

    /// Copies a file or folder into the shelf and returns its item. Does not insert it.
    static func copyIn(_ source: URL, root: URL) throws -> ShelfItem {
        let id = UUID()
        let folder = root.appendingPathComponent(id.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let fileName = source.lastPathComponent.isEmpty ? "Untitled" : source.lastPathComponent
        let destination = folder.appendingPathComponent(fileName)
        do {
            try FileManager.default.copyItem(at: source, to: destination)
        } catch {
            try? FileManager.default.removeItem(at: folder)
            throw error
        }
        return ShelfItem(id: id, fileName: fileName, byteSize: size(of: destination))
    }

    /// Moves a file (e.g. a received file promise) into the shelf.
    static func moveIn(_ source: URL, root: URL) throws -> ShelfItem {
        let id = UUID()
        let folder = root.appendingPathComponent(id.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let destination = folder.appendingPathComponent(source.lastPathComponent)
        do {
            try FileManager.default.moveItem(at: source, to: destination)
        } catch {
            try? FileManager.default.removeItem(at: folder)
            throw error
        }
        return ShelfItem(id: id, fileName: destination.lastPathComponent, byteSize: size(of: destination))
    }

    /// Writes raw data (a dropped image or text snippet) as a new shelf file.
    static func write(_ data: Data, fileName: String, root: URL) throws -> ShelfItem {
        let id = UUID()
        let folder = root.appendingPathComponent(id.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let destination = folder.appendingPathComponent(fileName)
        try data.write(to: destination, options: .atomic)
        return ShelfItem(id: id, fileName: fileName, byteSize: Int64(data.count))
    }

    /// Bytes on disk, recursing into folders and packages.
    static func size(of url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileSizeKey]
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return 0 }
        if !isDirectory.boolValue {
            let values = try? url.resourceValues(forKeys: keys)
            return Int64(values?.fileSize ?? 0)
        }
        var total: Int64 = 0
        let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: Array(keys))
        while let file = enumerator?.nextObject() as? URL {
            let values = try? file.resourceValues(forKeys: keys)
            if values?.isRegularFile == true {
                total += Int64(values?.fileSize ?? 0)
            }
        }
        return total
    }

    // MARK: Mutations

    func insert(_ item: ShelfItem) {
        items.insert(item, at: 0)
        save()
    }

    func remove(ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        for item in items where ids.contains(item.id) {
            deleteFiles(of: item)
        }
        items.removeAll { ids.contains($0.id) }
        save()
    }

    /// Removes everything except pinned items.
    func clearUnpinned() {
        remove(ids: Set(items.filter { !$0.isPinned }.map(\.id)))
    }

    func setPinned(_ pinned: Bool, ids: Set<UUID>) {
        for index in items.indices where ids.contains(items[index].id) {
            items[index].isPinned = pinned
        }
        save()
    }

    /// Enforces the caps, removing the oldest unpinned items first. Pinned items are never pruned,
    /// even if they alone exceed the caps. Returns what was removed.
    @discardableResult
    func prune(maxItems: Int, maxBytes: Int64) -> [ShelfItem] {
        var removed: [ShelfItem] = []
        var count = items.count
        var bytes = totalBytes
        // Oldest first.
        for item in items.sorted(by: { $0.addedAt < $1.addedAt }) where !item.isPinned {
            guard count > maxItems || bytes > maxBytes else { break }
            removed.append(item)
            count -= 1
            bytes -= item.byteSize
        }
        remove(ids: Set(removed.map(\.id)))
        if !removed.isEmpty {
            Log.shelf.info("Pruned \(removed.count, privacy: .public) item(s) to stay within caps")
        }
        return removed
    }

    // MARK: Persistence

    func save() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(items)
            try data.write(to: manifestURL, options: .atomic)
        } catch {
            Log.shelf.error("Failed to save shelf manifest: \(error.localizedDescription, privacy: .public)")
        }
    }

    func load() {
        guard let data = try? Data(contentsOf: manifestURL) else {
            items = []
            return
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = (try? decoder.decode([ShelfItem].self, from: data)) ?? []
        // Drop entries whose files have gone missing, rather than showing dead tiles.
        items = decoded.filter { FileManager.default.fileExists(atPath: url(for: $0).path) }
        if items.count != decoded.count { save() }
    }

    private func deleteFiles(of item: ShelfItem) {
        try? FileManager.default.removeItem(at: root.appendingPathComponent(item.id.uuidString, isDirectory: true))
    }
}
