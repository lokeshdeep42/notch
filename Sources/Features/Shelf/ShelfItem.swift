import Foundation

/// A file held on the shelf. The file itself is a *copy* living at `<root>/<id>/<fileName>`, so
/// moving or deleting the original never breaks the shelf.
struct ShelfItem: Codable, Identifiable, Equatable {
    let id: UUID
    let fileName: String
    let byteSize: Int64
    let addedAt: Date
    var isPinned: Bool

    init(id: UUID = UUID(), fileName: String, byteSize: Int64, addedAt: Date = Date(), isPinned: Bool = false) {
        self.id = id
        self.fileName = fileName
        self.byteSize = byteSize
        self.addedAt = addedAt
        self.isPinned = isPinned
    }
}
