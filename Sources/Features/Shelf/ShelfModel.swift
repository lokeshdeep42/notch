import AppKit
import Services

@MainActor
final class ShelfModel: ObservableObject {
    @Published private(set) var items: [ShelfItem] = []
    @Published var selection: Set<UUID> = []
    /// Files currently being copied in (shown as placeholders so big drops never look stuck).
    @Published private(set) var importing = 0
    @Published private(set) var lastError: String?

    let thumbnails = ThumbnailCache()
    private let preferences: Preferences
    private var store: ShelfStore?

    init(preferences: Preferences) {
        self.preferences = preferences
    }

    private var root: URL {
        Branding.supportDirectory.appendingPathComponent("Shelf", isDirectory: true)
    }

    func load() {
        guard store == nil else { return }
        let store = ShelfStore(root: root)
        store.prune(maxItems: preferences.shelfMaxItems, maxBytes: preferences.shelfMaxBytes)
        self.store = store
        publish()
    }

    func unload() {
        store = nil
        items = []
        selection = []
        thumbnails.purge()
    }

    func url(for item: ShelfItem) -> URL {
        ShelfStore.url(for: item, root: root)
    }

    var totalBytes: Int64 { items.reduce(0) { $0 + $1.byteSize } }

    // MARK: Import

    func importPayload(_ payload: ShelfPayload) {
        load()
        let root = self.root
        lastError = nil

        for url in payload.fileURLs {
            runImport { try ShelfStore.copyIn(url, root: root) }
        }
        if let data = payload.imageData {
            let name = ShelfImporter.snippetName(prefix: "Image", ext: "png")
            runImport { try ShelfStore.write(data, fileName: name, root: root) }
        }
        if let text = payload.text {
            let name = ShelfImporter.snippetName(prefix: "Text", ext: "txt")
            runImport { try ShelfStore.write(Data(text.utf8), fileName: name, root: root) }
        }
        for receiver in payload.promises {
            receivePromise(receiver, root: root)
        }
    }

    /// Copies off the main actor so a 1 GB drop never freezes the panel.
    private func runImport(_ work: @escaping @Sendable () throws -> ShelfItem) {
        importing += 1
        Task.detached(priority: .userInitiated) {
            let result = Result { try work() }
            await MainActor.run { [weak self] in
                self?.finishImport(result)
            }
        }
    }

    private func receivePromise(_ receiver: NSFilePromiseReceiver, root: URL) {
        let staging = FileManager.default.temporaryDirectory
            .appendingPathComponent("SillPromises-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        let queue = OperationQueue()
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 1
        importing += receiver.fileNames.count > 0 ? receiver.fileNames.count : 1
        let expected = max(receiver.fileNames.count, 1)
        var delivered = 0

        receiver.receivePromisedFiles(atDestination: staging, options: [:], operationQueue: queue) { fileURL, error in
            let result: Result<ShelfItem, Error>
            if let error {
                result = .failure(error)
            } else {
                result = Result { try ShelfStore.moveIn(fileURL, root: root) }
            }
            delivered += 1
            let finished = delivered >= expected
            Task { @MainActor [weak self] in
                self?.finishImport(result)
                if finished { try? FileManager.default.removeItem(at: staging) }
            }
        }
    }

    private func finishImport(_ result: Result<ShelfItem, Error>) {
        importing = max(importing - 1, 0)
        switch result {
        case let .success(item):
            store?.insert(item)
            let removed = store?.prune(maxItems: preferences.shelfMaxItems, maxBytes: preferences.shelfMaxBytes) ?? []
            thumbnails.forget(Set(removed.map(\.id)))
            publish()
            Log.shelf.info("Added \(item.fileName, privacy: .private) (\(item.byteSize, privacy: .public) bytes)")
        case let .failure(error):
            lastError = error.localizedDescription
            Log.shelf.error("Import failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: Actions

    func remove(_ ids: Set<UUID>) {
        store?.remove(ids: ids)
        thumbnails.forget(ids)
        selection.subtract(ids)
        publish()
    }

    func clearUnpinned() {
        let removed = Set(items.filter { !$0.isPinned }.map(\.id))
        store?.clearUnpinned()
        thumbnails.forget(removed)
        selection.subtract(removed)
        publish()
    }

    func togglePin(_ ids: Set<UUID>) {
        let pin = items.filter { ids.contains($0.id) }.contains { !$0.isPinned }
        store?.setPinned(pin, ids: ids)
        publish()
    }

    func open(_ ids: Set<UUID>) {
        for item in items where ids.contains(item.id) {
            NSWorkspace.shared.open(url(for: item))
        }
    }

    func reveal(_ ids: Set<UUID>) {
        let urls = items.filter { ids.contains($0.id) }.map { url(for: $0) }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    /// Click handling: plain click selects one, ⌘ toggles, ⇧ extends.
    func click(_ id: UUID, modifiers: NSEvent.ModifierFlags) {
        if modifiers.contains(.command) {
            if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
        } else if modifiers.contains(.shift), let anchor = items.firstIndex(where: { selection.contains($0.id) }),
                  let target = items.firstIndex(where: { $0.id == id }) {
            let range = min(anchor, target)...max(anchor, target)
            selection = Set(items[range].map(\.id))
        } else {
            selection = [id]
        }
    }

    /// The items a drag starting on `id` should carry: the whole selection if `id` is in it.
    func dragSet(startingAt id: UUID) -> [ShelfItem] {
        if selection.contains(id) {
            return items.filter { selection.contains($0.id) }
        }
        return items.filter { $0.id == id }
    }

    private func publish() {
        items = store?.items ?? []
        thumbnails.generate(for: items.map { (id: $0.id, url: url(for: $0)) })
    }
}
