import Foundation

struct ClipEntry: Codable, Identifiable, Equatable {
    enum Kind: String, Codable {
        case text
        case image
        case files
    }

    let id: UUID
    let kind: Kind
    /// Text content (for `.text`).
    var text: String?
    /// Absolute paths (for `.files`). The files are *not* copied — this is history, not a shelf.
    var filePaths: [String]?
    /// Full-resolution PNG and a small preview, stored beside the manifest (for `.image`).
    var imageFileName: String?
    var thumbnailFileName: String?
    var sourceAppName: String?
    var sourceBundleID: String?
    var createdAt: Date
    var byteSize: Int64

    init(id: UUID = UUID(), kind: Kind, text: String? = nil, filePaths: [String]? = nil,
         imageFileName: String? = nil, thumbnailFileName: String? = nil,
         sourceAppName: String? = nil, sourceBundleID: String? = nil,
         createdAt: Date = Date(), byteSize: Int64 = 0) {
        self.id = id
        self.kind = kind
        self.text = text
        self.filePaths = filePaths
        self.imageFileName = imageFileName
        self.thumbnailFileName = thumbnailFileName
        self.sourceAppName = sourceAppName
        self.sourceBundleID = sourceBundleID
        self.createdAt = createdAt
        self.byteSize = byteSize
    }

    /// One-line preview for the list.
    var preview: String {
        switch kind {
        case .text:
            return (text ?? "")
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        case .files:
            let names = (filePaths ?? []).map { ($0 as NSString).lastPathComponent }
            return names.joined(separator: ", ")
        case .image:
            return String(localized: "Image", comment: "Clipboard entry kind")
        }
    }

    /// Same content as another entry, ignoring when and where it was copied.
    func hasSameContent(as other: ClipEntry) -> Bool {
        kind == other.kind && text == other.text && filePaths == other.filePaths
            && (kind != .image || byteSize == other.byteSize)
    }

    func matches(_ query: String) -> Bool {
        guard !query.isEmpty else { return true }
        return preview.localizedCaseInsensitiveContains(query)
            || (sourceAppName?.localizedCaseInsensitiveContains(query) ?? false)
    }
}
