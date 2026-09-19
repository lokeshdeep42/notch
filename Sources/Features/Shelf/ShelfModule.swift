import AppKit
import NotchCore
import Services
import SwiftUI

@MainActor
public final class ShelfModule: DropAcceptingModule {
    public let id = "shelf"
    public let symbolName = "tray"
    public var title: String { String(localized: "Shelf", comment: "Module name") }
    public var isEnabled: Bool { preferences.shelfEnabled }

    private let preferences: Preferences
    private let model: ShelfModel

    public init(preferences: Preferences) {
        self.preferences = preferences
        model = ShelfModel(preferences: preferences)
    }

    public func makeExpandedView() -> AnyView {
        AnyView(ShelfView(model: model, thumbnails: model.thumbnails))
    }

    /// No observers or timers: the shelf only does work when something is dropped.
    public func activate(host: NotchHost) {
        model.load()
    }

    public func deactivate() {
        model.unload()
    }

    public func handleDrop(_ pasteboard: NSPasteboard) -> Bool {
        guard let payload = ShelfImporter.read(pasteboard) else { return false }
        model.importPayload(payload)
        return true
    }
}
