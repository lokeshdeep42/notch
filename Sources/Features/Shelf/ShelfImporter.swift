import AppKit
import UniformTypeIdentifiers

/// Everything the shelf can take from a drop, read synchronously while the drag pasteboard is
/// still valid. The slow part (copying) happens later, off the main actor.
struct ShelfPayload {
    var fileURLs: [URL] = []
    /// Photos, Mail and some browsers drag *promises* rather than files.
    var promises: [NSFilePromiseReceiver] = []
    var imageData: Data?
    var text: String?

    var isEmpty: Bool { fileURLs.isEmpty && promises.isEmpty && imageData == nil && text == nil }
}

@MainActor
enum ShelfImporter {
    static func read(_ pasteboard: NSPasteboard) -> ShelfPayload? {
        var payload = ShelfPayload()

        if let urls = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL], !urls.isEmpty {
            payload.fileURLs = urls
            return payload
        }

        if let receivers = pasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self]) as? [NSFilePromiseReceiver],
           !receivers.isEmpty {
            payload.promises = receivers
            return payload
        }

        if let png = pasteboard.data(forType: .png) {
            payload.imageData = png
        } else if let tiff = pasteboard.data(forType: .tiff),
                  let rep = NSBitmapImageRep(data: tiff),
                  let png = rep.representation(using: .png, properties: [:]) {
            payload.imageData = png
        } else if let string = pasteboard.string(forType: .string), !string.isEmpty {
            payload.text = string
        }
        return payload.isEmpty ? nil : payload
    }

    /// A readable file name for a dropped snippet, e.g. "Text 2026-09-19 at 14.03.txt".
    static func snippetName(prefix: String, ext: String, date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return "\(prefix) \(formatter.string(from: date)).\(ext)"
    }
}
