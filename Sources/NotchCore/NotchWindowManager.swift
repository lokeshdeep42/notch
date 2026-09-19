import AppKit
import Combine
import Services

/// Owns one `NotchPanelController` per eligible display and keeps that set correct through
/// plug/unplug, resolution and arrangement changes, sleep/wake, lock, fast user switching,
/// fullscreen apps and the user's pause switch.
///
/// Design rule: never move a window between screens. Reconciliation diffs the desired set against
/// the live controllers and creates/destroys; it is idempotent, so bursts of notifications are safe.
@MainActor
public final class NotchWindowManager {
    private let hub: NotchHub
    private let preferences: Preferences
    private let magnet = DragMagnet.shared

    private var controllers: [CGDirectDisplayID: NotchPanelController] = [:]
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var cancellables: Set<AnyCancellable> = []
    private var reconcileTask: Task<Void, Never>?

    private var screensAsleep = false
    private var sessionActive = true
    private var screenLocked = false

    public init(hub: NotchHub, preferences: Preferences) {
        self.hub = hub
        self.preferences = preferences
    }

    public func start() {
        wireHub()
        wireMagnet()
        observeSystem()
        preferences.objectWillChange
            .sink { [weak self] _ in self?.scheduleReconcile(after: 0.05) }
            .store(in: &cancellables)
        reconcile()
    }

    public func stop() {
        reconcileTask?.cancel()
        for (center, token) in observers {
            center.removeObserver(token)
        }
        observers.removeAll()
        cancellables.removeAll()
        magnet.stop()
        controllers.values.forEach { $0.tearDown() }
        controllers.removeAll()
    }

    public var activeDisplayCount: Int { controllers.count }

    // MARK: Wiring

    private func wireHub() {
        hub.peekHandler = { [weak self] peek in
            self?.controllers.values.forEach { $0.showPeek(peek) }
        }
        hub.collapseHandler = { [weak self] in
            self?.controllers.values.forEach { $0.collapse() }
        }
        hub.selectionHandler = { [weak self] in
            self?.controllers.values.forEach { $0.updateKeyStatus() }
        }
        hub.wingsHandler = { [weak self] in
            self?.controllers.values.forEach { $0.refreshInteraction() }
        }
    }

    private func wireMagnet() {
        magnet.onFileDrag = { [weak self] point in
            self?.controllers.values.forEach { $0.handleFileDrag(at: point) }
        }
        magnet.onDragEnded = { [weak self] in
            self?.controllers.values.forEach { $0.handleDragEnded() }
        }
    }

    private func observeSystem() {
        let center = NotificationCenter.default
        let workspace = NSWorkspace.shared.notificationCenter
        let distributed = DistributedNotificationCenter.default()

        observe(center, NSApplication.didChangeScreenParametersNotification) { manager in
            // Fires in bursts on plug/unplug and scaling changes.
            manager.scheduleReconcile(after: 0.3)
        }
        observe(workspace, NSWorkspace.screensDidSleepNotification) { manager in
            manager.screensAsleep = true
            manager.reconcile()
        }
        observe(workspace, NSWorkspace.screensDidWakeNotification) { manager in
            manager.screensAsleep = false
            manager.scheduleReconcile(after: 0.3)
        }
        observe(workspace, NSWorkspace.didWakeNotification) { manager in
            manager.screensAsleep = false
            manager.scheduleReconcile(after: 0.5)
        }
        observe(workspace, NSWorkspace.sessionDidResignActiveNotification) { manager in
            manager.sessionActive = false
            manager.reconcile()
        }
        observe(workspace, NSWorkspace.sessionDidBecomeActiveNotification) { manager in
            manager.sessionActive = true
            manager.scheduleReconcile(after: 0.3)
        }
        observe(workspace, NSWorkspace.activeSpaceDidChangeNotification) { manager in
            manager.scheduleReconcile(after: 0.15)
        }
        observe(workspace, NSWorkspace.didActivateApplicationNotification) { manager in
            manager.scheduleReconcile(after: 0.15)
        }
        observe(distributed, Notification.Name("com.apple.screenIsLocked")) { manager in
            manager.screenLocked = true
            manager.reconcile()
        }
        observe(distributed, Notification.Name("com.apple.screenIsUnlocked")) { manager in
            manager.screenLocked = false
            manager.scheduleReconcile(after: 0.3)
        }
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name,
                         _ handler: @escaping @MainActor (NotchWindowManager) -> Void) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                handler(self)
            }
        }
        observers.append((center, token))
    }

    // MARK: Reconciliation

    /// Debounced with a one-shot task; never a repeating timer.
    func scheduleReconcile(after seconds: Double) {
        reconcileTask?.cancel()
        reconcileTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.reconcile()
        }
    }

    func reconcile() {
        reconcileTask?.cancel()
        reconcileTask = nil

        let desired = desiredDisplays()

        for (id, controller) in controllers {
            let wanted = desired[id]
            if wanted == nil || wanted?.geometry != controller.geometry {
                controller.tearDown()
                controllers.removeValue(forKey: id)
            }
        }

        for (id, entry) in desired where controllers[id] == nil {
            let controller = NotchPanelController(
                displayID: id, geometry: entry.geometry, hub: hub,
                preferences: preferences, magnet: magnet
            )
            controllers[id] = controller
            controller.show()
        }

        controllers.values.forEach { $0.refreshInteraction() }

        // The drag magnet only listens while there is a panel that could accept a drop.
        if !controllers.isEmpty, hub.dropModule != nil {
            magnet.start()
        } else {
            magnet.stop()
        }

        Log.display.info("Reconciled: \(self.controllers.count, privacy: .public) panel(s)")
    }

    private struct DesiredDisplay {
        let screen: NSScreen
        let geometry: NotchGeometry
    }

    private func desiredDisplays() -> [CGDirectDisplayID: DesiredDisplay] {
        guard !preferences.isPaused, !screensAsleep, sessionActive, !screenLocked else { return [:] }

        let screens = NSScreen.screens.compactMap { screen -> (CGDirectDisplayID, NSScreen)? in
            guard let id = screen.displayID else { return nil }
            return (id, screen)
        }
        guard !screens.isEmpty else { return [:] }

        let eligible: [(CGDirectDisplayID, NSScreen)]
        switch preferences.displayMode {
        case .all:
            eligible = screens
        case .builtInOnly:
            let builtIn = screens.filter { CGDisplayIsBuiltin($0.0) != 0 }
            // Clamshell mode: no built-in display is active. Fall back to the menu-bar display
            // rather than silently showing nothing — "doesn't work on my monitor" is the complaint
            // this product exists to fix.
            eligible = builtIn.isEmpty ? Array(screens.prefix(1)) : builtIn
        case .chosen:
            let chosen = Set(preferences.chosenDisplayUUIDs)
            let picked = screens.filter { chosen.contains(Self.uuidString(for: $0.0) ?? "") }
            eligible = picked.isEmpty ? Array(screens.prefix(1)) : picked
        }

        let fullscreen = FullscreenDetector.fullscreenDisplayIDs(among: eligible.map { $0.0 })
        var result: [CGDirectDisplayID: DesiredDisplay] = [:]
        for (id, screen) in eligible where !fullscreen.contains(id) {
            let geometry = NotchGeometry.resolve(screen: screen, fallbackWidth: CGFloat(preferences.pillWidth))
            result[id] = DesiredDisplay(screen: screen, geometry: geometry)
        }
        return result
    }

    // MARK: Display identity

    /// Stable across reboots, unlike `CGDirectDisplayID`. Used for the "chosen displays" setting.
    public static func uuidString(for displayID: CGDirectDisplayID) -> String? {
        guard let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue() else { return nil }
        return CFUUIDCreateString(nil, uuid) as String?
    }

    public struct ConnectedDisplay: Identifiable, Equatable {
        public let uuid: String
        public let name: String
        public let isBuiltIn: Bool
        public var id: String { uuid }
    }

    /// Display name and UUID for every connected screen, for the settings UI.
    public static func connectedDisplays() -> [ConnectedDisplay] {
        NSScreen.screens.compactMap { screen in
            guard let id = screen.displayID, let uuid = uuidString(for: id) else { return nil }
            return ConnectedDisplay(uuid: uuid, name: screen.localizedName, isBuiltIn: CGDisplayIsBuiltin(id) != 0)
        }
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
