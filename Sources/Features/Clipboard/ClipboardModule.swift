import Combine
import NotchCore
import Services
import SwiftUI

/// The tab is always present so the feature is discoverable, but *capture* is off by default and
/// the pasteboard is never read until the user turns it on (permission hygiene, see the spec).
@MainActor
public final class ClipboardModule: NotchModule {
    public let id = "clipboard"
    public let symbolName = "doc.on.clipboard"
    public var title: String { String(localized: "Clipboard", comment: "Module name") }
    public var isEnabled: Bool { true }
    public var wantsKeyboardFocus: Bool { preferences.clipboardEnabled }

    private let preferences: Preferences
    private let model: ClipboardModel
    private weak var host: NotchHost?
    private var cancellables: Set<AnyCancellable> = []

    public init(preferences: Preferences) {
        self.preferences = preferences
        model = ClipboardModel(preferences: preferences)
    }

    public func makeExpandedView() -> AnyView {
        AnyView(ClipboardView(model: model, preferences: preferences))
    }

    public func activate(host: NotchHost) {
        self.host = host
        model.onCopied = { [weak host] in host?.requestCollapse() }
        preferences.$clipboardEnabled
            .combineLatest(preferences.$clipboardPaused, preferences.$clipboardMaxItems)
            .removeDuplicates { $0 == $1 }
            .sink { [weak self] _ in
                // @Published emits before the property is set; sync on the next turn.
                Task { @MainActor in self?.model.sync() }
            }
            .store(in: &cancellables)
        // Turning capture on from the panel: re-select the tab so the panel takes keyboard focus
        // for the search field straight away.
        preferences.$clipboardEnabled
            .dropFirst()
            .filter { $0 }
            .sink { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.host?.select(moduleID: self.id)
                }
            }
            .store(in: &cancellables)
    }

    public func deactivate() {
        cancellables.removeAll()
        model.shutdown()
        host = nil
    }

    public func panelDidOpen() {
        model.query = ""
        model.selectedIndex = 0
    }
}
