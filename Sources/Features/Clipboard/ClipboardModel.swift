import AppKit
import ImageIO
import Services

@MainActor
final class ClipboardModel: ObservableObject {
    @Published private(set) var entries: [ClipEntry] = []
    @Published var query = "" {
        didSet { selectedIndex = 0 }
    }
    @Published var selectedIndex = 0

    let preferences: Preferences
    var onCopied: (() -> Void)?

    private let monitor = ClipboardMonitor()
    private var store: ClipboardStore?

    init(preferences: Preferences) {
        self.preferences = preferences
        monitor.blocklist = { [weak preferences] in Set(preferences?.clipboardBlocklist ?? []) }
        monitor.onCapture = { [weak self] capture in self?.record(capture) }
    }

    private var root: URL {
        Branding.supportDirectory.appendingPathComponent("Clipboard", isDirectory: true)
    }

    var filtered: [ClipEntry] {
        entries.filter { $0.matches(query) }
    }

    var isCapturing: Bool { monitor.isRunning }

    // MARK: Lifecycle

    /// Starts or stops capture to match preferences. Idempotent.
    func sync() {
        let shouldCapture = preferences.clipboardEnabled && !preferences.clipboardPaused
        if preferences.clipboardEnabled {
            loadStore()
            store?.maxItems = preferences.clipboardMaxItems
            store?.prune()
            publish()
        }
        if shouldCapture {
            monitor.start()
        } else {
            monitor.stop()
        }
        objectWillChange.send()
    }

    func shutdown() {
        monitor.stop()
        store = nil
        entries = []
    }

    private func loadStore() {
        guard store == nil else { return }
        store = ClipboardStore(root: root, maxItems: preferences.clipboardMaxItems)
    }

    // MARK: Capture

    private func record(_ capture: ClipCapture) {
        loadStore()
        guard let store else { return }
        switch capture.kind {
        case .text:
            let text = capture.text ?? ""
            store.add(ClipEntry(kind: .text, text: text, sourceAppName: capture.sourceAppName,
                                sourceBundleID: capture.sourceBundleID, byteSize: Int64(text.utf8.count)))
        case .files:
            store.add(ClipEntry(kind: .files, filePaths: capture.fileURLs.map(\.path),
                                sourceAppName: capture.sourceAppName, sourceBundleID: capture.sourceBundleID))
        case .image:
            guard let data = capture.imageData else { return }
            store.add(
                ClipEntry(kind: .image, sourceAppName: capture.sourceAppName,
                          sourceBundleID: capture.sourceBundleID, byteSize: Int64(data.count)),
                imageData: data,
                thumbnailData: Self.thumbnail(of: data)
            )
        }
        publish()
    }

    private static func thumbnail(of data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 64,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    }

    // MARK: Actions

    /// Puts the entry back on the clipboard. The user pastes with ⌘V — synthesising the paste
    /// would need Accessibility permission, which v1 deliberately doesn't ask for.
    func copy(_ entry: ClipEntry) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        switch entry.kind {
        case .text:
            pasteboard.setString(entry.text ?? "", forType: .string)
        case .files:
            let urls = (entry.filePaths ?? []).map { URL(fileURLWithPath: $0) }
                .filter { FileManager.default.fileExists(atPath: $0.path) }
            pasteboard.writeObjects(urls as [NSURL])
        case .image:
            if let name = entry.imageFileName, let store, let data = try? Data(contentsOf: store.blobURL(name)) {
                pasteboard.setData(data, forType: .png)
            }
        }
        monitor.ignoreCurrentContents()
        // Move it to the top, like copying it again.
        store?.add(ClipEntry(kind: entry.kind, text: entry.text, filePaths: entry.filePaths,
                             sourceAppName: entry.sourceAppName, sourceBundleID: entry.sourceBundleID,
                             byteSize: entry.byteSize))
        publish()
        onCopied?()
    }

    func copySelected() {
        let list = filtered
        guard list.indices.contains(selectedIndex) else { return }
        copy(list[selectedIndex])
    }

    func moveSelection(by delta: Int) {
        let count = filtered.count
        guard count > 0 else { return }
        selectedIndex = min(max(selectedIndex + delta, 0), count - 1)
    }

    func delete(_ entry: ClipEntry) {
        store?.remove(ids: [entry.id])
        publish()
    }

    func clearAll() {
        store?.removeAll()
        publish()
    }

    private var thumbnailCache: [UUID: NSImage] = [:]

    func thumbnail(for entry: ClipEntry) -> NSImage? {
        if let cached = thumbnailCache[entry.id] { return cached }
        guard let name = entry.thumbnailFileName, let store,
              let image = NSImage(contentsOf: store.blobURL(name)) else { return nil }
        thumbnailCache[entry.id] = image
        return image
    }

    private func publish() {
        entries = store?.entries ?? []
        if selectedIndex >= filtered.count {
            selectedIndex = max(filtered.count - 1, 0)
        }
    }
}
