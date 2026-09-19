import Foundation
import Combine

public enum DisplayMode: String, CaseIterable, Identifiable, Sendable {
    case builtInOnly
    case all
    case chosen

    public var id: String { rawValue }
}

/// Typed, observable user preferences backed by `UserDefaults`.
/// Every property writes through on change, so values persist without an explicit save.
@MainActor
public final class Preferences: ObservableObject {
    public static let shared = Preferences()

    private let defaults: UserDefaults

    // MARK: Hover
    @Published public var enterDelay: Double { didSet { defaults.set(enterDelay, forKey: Key.enterDelay) } }
    @Published public var exitDelay: Double { didSet { defaults.set(exitDelay, forKey: Key.exitDelay) } }
    @Published public var deadZone: Double { didSet { defaults.set(deadZone, forKey: Key.deadZone) } }
    @Published public var intentHover: Bool { didSet { defaults.set(intentHover, forKey: Key.intentHover) } }

    // MARK: Displays & appearance
    @Published public var displayMode: DisplayMode {
        didSet { defaults.set(displayMode.rawValue, forKey: Key.displayMode) }
    }
    @Published public var chosenDisplayUUIDs: [String] {
        didSet { defaults.set(chosenDisplayUUIDs, forKey: Key.chosenDisplayUUIDs) }
    }
    @Published public var pillWidth: Double { didSet { defaults.set(pillWidth, forKey: Key.pillWidth) } }
    @Published public var showBatteryWhenCollapsed: Bool {
        didSet { defaults.set(showBatteryWhenCollapsed, forKey: Key.showBatteryWhenCollapsed) }
    }

    // MARK: Modules
    @Published public var nowPlayingEnabled: Bool {
        didSet { defaults.set(nowPlayingEnabled, forKey: Key.nowPlayingEnabled) }
    }
    @Published public var shelfEnabled: Bool { didSet { defaults.set(shelfEnabled, forKey: Key.shelfEnabled) } }
    @Published public var clipboardEnabled: Bool {
        didSet { defaults.set(clipboardEnabled, forKey: Key.clipboardEnabled) }
    }
    @Published public var powerEnabled: Bool { didSet { defaults.set(powerEnabled, forKey: Key.powerEnabled) } }

    // MARK: Clipboard
    @Published public var clipboardPaused: Bool {
        didSet { defaults.set(clipboardPaused, forKey: Key.clipboardPaused) }
    }
    @Published public var clipboardMaxItems: Int {
        didSet { defaults.set(clipboardMaxItems, forKey: Key.clipboardMaxItems) }
    }
    @Published public var clipboardBlocklist: [String] {
        didSet { defaults.set(clipboardBlocklist, forKey: Key.clipboardBlocklist) }
    }

    // MARK: Shelf
    @Published public var shelfMaxItems: Int { didSet { defaults.set(shelfMaxItems, forKey: Key.shelfMaxItems) } }
    @Published public var shelfMaxBytes: Int64 {
        didSet { defaults.set(shelfMaxBytes, forKey: Key.shelfMaxBytes) }
    }

    // MARK: App
    @Published public var isPaused: Bool { didSet { defaults.set(isPaused, forKey: Key.isPaused) } }
    @Published public var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Key.hasCompletedOnboarding) }
    }
    /// Enable with `defaults write app.sill.Sill DebugOverlay -bool YES`, or from Advanced settings.
    @Published public var debugOverlay: Bool { didSet { defaults.set(debugOverlay, forKey: Key.debugOverlay) } }

    public static let defaultClipboardBlocklist = [
        "com.1password.1password",
        "com.agilebits.onepassword7",
        "com.bitwarden.desktop",
        "com.apple.keychainaccess",
        "com.apple.Passwords",
        "com.dashlane.dashlanephonefinal",
        "org.keepassxc.keepassxc",
    ]

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        enterDelay = defaults.object(forKey: Key.enterDelay) as? Double ?? 0.18
        exitDelay = defaults.object(forKey: Key.exitDelay) as? Double ?? 0.25
        deadZone = defaults.object(forKey: Key.deadZone) as? Double ?? 3
        intentHover = defaults.object(forKey: Key.intentHover) as? Bool ?? true
        displayMode = (defaults.string(forKey: Key.displayMode)).flatMap(DisplayMode.init(rawValue:)) ?? .builtInOnly
        chosenDisplayUUIDs = defaults.stringArray(forKey: Key.chosenDisplayUUIDs) ?? []
        pillWidth = defaults.object(forKey: Key.pillWidth) as? Double ?? 185
        showBatteryWhenCollapsed = defaults.object(forKey: Key.showBatteryWhenCollapsed) as? Bool ?? false
        nowPlayingEnabled = defaults.object(forKey: Key.nowPlayingEnabled) as? Bool ?? true
        shelfEnabled = defaults.object(forKey: Key.shelfEnabled) as? Bool ?? true
        clipboardEnabled = defaults.object(forKey: Key.clipboardEnabled) as? Bool ?? false
        powerEnabled = defaults.object(forKey: Key.powerEnabled) as? Bool ?? true
        clipboardPaused = defaults.object(forKey: Key.clipboardPaused) as? Bool ?? false
        clipboardMaxItems = defaults.object(forKey: Key.clipboardMaxItems) as? Int ?? 200
        clipboardBlocklist = defaults.stringArray(forKey: Key.clipboardBlocklist) ?? Self.defaultClipboardBlocklist
        shelfMaxItems = defaults.object(forKey: Key.shelfMaxItems) as? Int ?? 100
        shelfMaxBytes = (defaults.object(forKey: Key.shelfMaxBytes) as? NSNumber)?.int64Value ?? 2_000_000_000
        isPaused = defaults.object(forKey: Key.isPaused) as? Bool ?? false
        hasCompletedOnboarding = defaults.object(forKey: Key.hasCompletedOnboarding) as? Bool ?? false
        debugOverlay = defaults.object(forKey: Key.debugOverlay) as? Bool ?? false
    }

    /// Restores every hover and appearance preference to its shipped default.
    public func resetHoverTuning() {
        enterDelay = 0.18
        exitDelay = 0.25
        deadZone = 3
        intentHover = true
    }

    private enum Key {
        static let enterDelay = "EnterDelay"
        static let exitDelay = "ExitDelay"
        static let deadZone = "DeadZone"
        static let intentHover = "IntentHover"
        static let displayMode = "DisplayMode"
        static let chosenDisplayUUIDs = "ChosenDisplayUUIDs"
        static let pillWidth = "PillWidth"
        static let showBatteryWhenCollapsed = "ShowBatteryWhenCollapsed"
        static let nowPlayingEnabled = "NowPlayingEnabled"
        static let shelfEnabled = "ShelfEnabled"
        static let clipboardEnabled = "ClipboardEnabled"
        static let powerEnabled = "PowerEnabled"
        static let clipboardPaused = "ClipboardPaused"
        static let clipboardMaxItems = "ClipboardMaxItems"
        static let clipboardBlocklist = "ClipboardBlocklist"
        static let shelfMaxItems = "ShelfMaxItems"
        static let shelfMaxBytes = "ShelfMaxBytes"
        static let isPaused = "IsPaused"
        static let hasCompletedOnboarding = "HasCompletedOnboarding"
        static let debugOverlay = "DebugOverlay"
    }
}
