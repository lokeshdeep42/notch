import AppKit
import QuickLookThumbnailing

/// Quick Look thumbnails, generated once per item off the main actor and kept in memory.
/// Until a thumbnail arrives, the Finder icon stands in.
@MainActor
final class ThumbnailCache: ObservableObject {
    @Published private(set) var images: [UUID: NSImage] = [:]
    private var requested: Set<UUID> = []

    static let pointSize = CGSize(width: 56, height: 56)

    func image(for id: UUID, at url: URL) -> NSImage {
        images[id] ?? NSWorkspace.shared.icon(forFile: url.path)
    }

    func generate(for items: [(id: UUID, url: URL)]) {
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        for item in items where !requested.contains(item.id) {
            requested.insert(item.id)
            let request = QLThumbnailGenerator.Request(
                fileAt: item.url, size: Self.pointSize, scale: scale, representationTypes: .all
            )
            let id = item.id
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
                guard let image = representation?.nsImage else { return }
                Task { @MainActor [weak self] in
                    self?.images[id] = image
                }
            }
        }
    }

    func forget(_ ids: Set<UUID>) {
        for id in ids {
            images.removeValue(forKey: id)
            requested.remove(id)
        }
    }

    func purge() {
        images.removeAll()
        requested.removeAll()
    }
}
