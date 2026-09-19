import AppKit
import NotchCore
import Services
import SwiftUI

struct SettingsView: View {
    @ObservedObject var preferences: Preferences
    @ObservedObject var launchAtLogin: LaunchAtLogin
    @ObservedObject var permissions: PermissionService
    @State var initialTab: SettingsTab

    init(preferences: Preferences, launchAtLogin: LaunchAtLogin, permissions: PermissionService,
         initialTab: SettingsTab) {
        self.preferences = preferences
        self.launchAtLogin = launchAtLogin
        self.permissions = permissions
        _initialTab = State(initialValue: initialTab)
    }

    var body: some View {
        TabView(selection: $initialTab) {
            GeneralTab(preferences: preferences, launchAtLogin: launchAtLogin)
                .tabItem { Label(String(localized: "General", comment: "Settings tab"), systemImage: "gearshape") }
                .tag(SettingsTab.general)
            HoverTab(preferences: preferences)
                .tabItem { Label(String(localized: "Hover", comment: "Settings tab"), systemImage: "cursorarrow.motionlines") }
                .tag(SettingsTab.hover)
            ModulesTab(preferences: preferences)
                .tabItem { Label(String(localized: "Modules", comment: "Settings tab"), systemImage: "square.grid.2x2") }
                .tag(SettingsTab.modules)
            AdvancedTab(preferences: preferences, permissions: permissions)
                .tabItem { Label(String(localized: "Advanced", comment: "Settings tab"), systemImage: "wrench.and.screwdriver") }
                .tag(SettingsTab.advanced)
            AboutTab()
                .tabItem { Label(String(localized: "About", comment: "Settings tab"), systemImage: "info.circle") }
                .tag(SettingsTab.about)
        }
        .frame(width: 580, height: 480)
    }
}

// MARK: - General

private struct GeneralTab: View {
    @ObservedObject var preferences: Preferences
    @ObservedObject var launchAtLogin: LaunchAtLogin
    @State private var displays = NotchWindowManager.connectedDisplays()

    var body: some View {
        Form {
            Section {
                Toggle(String(localized: "Launch at login", comment: "Setting"), isOn: Binding(
                    get: { launchAtLogin.isOn },
                    set: { launchAtLogin.setEnabled($0) }
                ))
                switch launchAtLogin.status {
                case .requiresApproval:
                    HStack {
                        Text(String(localized: "macOS needs you to allow this in Login Items.", comment: "Launch at login status"))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(String(localized: "Open Login Items", comment: "Button")) {
                            launchAtLogin.openLoginItemsSettings()
                        }
                    }
                case let .failed(message):
                    Text(message).foregroundStyle(.red)
                case .enabled, .disabled:
                    EmptyView()
                }
                Toggle(String(localized: "Pause \(Branding.appName)", comment: "Setting"), isOn: $preferences.isPaused)
            }

            Section {
                Picker(String(localized: "Show on", comment: "Setting: which displays"), selection: $preferences.displayMode) {
                    Text(String(localized: "Built-in display", comment: "Display mode")).tag(DisplayMode.builtInOnly)
                    Text(String(localized: "All displays", comment: "Display mode")).tag(DisplayMode.all)
                    Text(String(localized: "Chosen displays", comment: "Display mode")).tag(DisplayMode.chosen)
                }
                if preferences.displayMode == .chosen {
                    ForEach(displays) { display in
                        Toggle(display.name + (display.isBuiltIn ? String(localized: " (built-in)", comment: "Display suffix") : ""),
                               isOn: Binding(
                                   get: { preferences.chosenDisplayUUIDs.contains(display.uuid) },
                                   set: { on in
                                       var set = Set(preferences.chosenDisplayUUIDs)
                                       if on { set.insert(display.uuid) } else { set.remove(display.uuid) }
                                       preferences.chosenDisplayUUIDs = Array(set)
                                   }
                               ))
                    }
                }
                if preferences.displayMode == .builtInOnly {
                    Text(String(localized: "With the lid closed, the panel moves to your main display.", comment: "Display mode hint"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading) {
                    Slider(value: $preferences.pillWidth, in: 140...300, step: 5) {
                        Text(String(localized: "Pill width on displays without a notch", comment: "Setting"))
                    }
                    Text(verbatim: "\(Int(preferences.pillWidth)) pt")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text(String(localized: "Displays", comment: "Settings section"))
            }
        }
        .formStyle(.grouped)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            displays = NotchWindowManager.connectedDisplays()
        }
    }
}

// MARK: - Hover

private struct HoverTab: View {
    @ObservedObject var preferences: Preferences

    var body: some View {
        Form {
            Section {
                labeledSlider(
                    String(localized: "Open after", comment: "Hover setting"),
                    value: $preferences.enterDelay, range: 0...0.8, step: 0.02,
                    format: { "\(Int(($0 * 1000).rounded())) ms" }
                )
                labeledSlider(
                    String(localized: "Close after", comment: "Hover setting"),
                    value: $preferences.exitDelay, range: 0...1.0, step: 0.02,
                    format: { "\(Int(($0 * 1000).rounded())) ms" }
                )
                labeledSlider(
                    String(localized: "Menu bar dead zone", comment: "Hover setting"),
                    value: $preferences.deadZone, range: 0...10, step: 1,
                    format: { "\(Int($0)) pt" }
                )
            } footer: {
                Text(String(localized: "The dead zone ignores the top few points of the screen, so throwing the pointer at the menu bar doesn't open the panel. Changes apply immediately — try the notch now.", comment: "Hover footer"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle(String(localized: "Open when the pointer settles", comment: "Intent hover setting"),
                       isOn: $preferences.intentHover)
            } footer: {
                Text(String(localized: "\(Branding.appName) watches how the pointer moves inside the notch. Slow down there and it opens right away; race through toward the menu bar and it waits.", comment: "Intent hover footer"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button(String(localized: "Restore defaults", comment: "Button")) {
                    preferences.resetHoverTuning()
                }
            }
        }
        .formStyle(.grouped)
    }

    private func labeledSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>,
                               step: Double, format: @escaping (Double) -> String) -> some View {
        HStack {
            Text(title)
                .frame(width: 140, alignment: .leading)
            Slider(value: value, in: range, step: step)
            Text(verbatim: format(value.wrappedValue))
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .trailing)
        }
    }
}

// MARK: - Modules

private struct ModulesTab: View {
    @ObservedObject var preferences: Preferences
    @State private var newBundleID = ""

    private struct ShelfSize: Identifiable {
        let label: String
        let bytes: Int64
        var id: Int64 { bytes }
    }

    private static let shelfSizes = [
        ShelfSize(label: "500 MB", bytes: 500_000_000), ShelfSize(label: "1 GB", bytes: 1_000_000_000),
        ShelfSize(label: "2 GB", bytes: 2_000_000_000), ShelfSize(label: "5 GB", bytes: 5_000_000_000),
    ]

    private struct RunningApp: Identifiable {
        let bundleID: String
        let name: String
        var id: String { bundleID }
    }

    var body: some View {
        Form {
            Section {
                Toggle(String(localized: "Now Playing", comment: "Module toggle"), isOn: $preferences.nowPlayingEnabled)
                Text(String(localized: "Event-driven: costs nothing while nothing changes.", comment: "Module cost note"))
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section {
                Toggle(String(localized: "Shelf", comment: "Module toggle"), isOn: $preferences.shelfEnabled)
                if preferences.shelfEnabled {
                    Stepper(value: $preferences.shelfMaxItems, in: 10...500, step: 10) {
                        Text(String(localized: "Keep up to \(preferences.shelfMaxItems) items", comment: "Shelf cap"))
                    }
                    Picker(String(localized: "Maximum size", comment: "Shelf cap"), selection: $preferences.shelfMaxBytes) {
                        ForEach(Self.shelfSizes) { size in
                            Text(size.label).tag(size.bytes)
                        }
                    }
                }
                Text(String(localized: "Does nothing until you drop a file. Oldest unpinned items go first when full.", comment: "Module cost note"))
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section {
                Toggle(String(localized: "Clipboard history", comment: "Module toggle"), isOn: $preferences.clipboardEnabled)
                Text(String(localized: "Cost: reads one counter once a second while on — every 10 s when you're away, and not at all while your Mac sleeps or is locked. Password-manager copies are never kept.", comment: "Clipboard cost note"))
                    .font(.caption).foregroundStyle(.secondary)
                if preferences.clipboardEnabled {
                    Stepper(value: $preferences.clipboardMaxItems, in: 20...1000, step: 20) {
                        Text(String(localized: "Keep up to \(preferences.clipboardMaxItems) entries", comment: "Clipboard cap"))
                    }
                    blocklist
                }
            }

            Section {
                Toggle(String(localized: "Battery", comment: "Module toggle"), isOn: $preferences.powerEnabled)
                if preferences.powerEnabled {
                    Toggle(String(localized: "Show battery beside the notch", comment: "Setting"),
                           isOn: $preferences.showBatteryWhenCollapsed)
                }
                Text(String(localized: "Updates only when macOS reports a change. The charger peek appears either way.", comment: "Module cost note"))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private var blocklist: some View {
        DisclosureGroup(String(localized: "Never record from these apps", comment: "Clipboard blocklist")) {
            ForEach(preferences.clipboardBlocklist, id: \.self) { bundleID in
                HStack {
                    Text(Self.appName(for: bundleID))
                    Text(bundleID).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        preferences.clipboardBlocklist.removeAll { $0 == bundleID }
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(Text(String(localized: "Remove", comment: "Button")))
                }
            }
            Menu(String(localized: "Add a running app", comment: "Clipboard blocklist")) {
                ForEach(Self.runningApps(excluding: preferences.clipboardBlocklist)) { app in
                    Button(app.name) {
                        preferences.clipboardBlocklist.append(app.bundleID)
                    }
                }
            }
        }
    }

    private static func appName(for bundleID: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return bundleID }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }

    private static func runningApps(excluding: [String]) -> [RunningApp] {
        let excluded = Set(excluding)
        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> RunningApp? in
                guard let id = app.bundleIdentifier, !excluded.contains(id) else { return nil }
                return RunningApp(bundleID: id, name: app.localizedName ?? id)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

// MARK: - Advanced

private struct AdvancedTab: View {
    @ObservedObject var preferences: Preferences
    @ObservedObject var permissions: PermissionService
    @State private var receipt = CostSample.current().map(CostReceipt.init(sample:))

    var body: some View {
        Form {
            Section {
                if let receipt {
                    LabeledContent(String(localized: "CPU since launch", comment: "Cost"), value: receipt.cpuText)
                    LabeledContent(String(localized: "Wakeups per hour", comment: "Cost"), value: receipt.wakeupsText)
                    LabeledContent(String(localized: "Memory", comment: "Cost"), value: receipt.memoryText)
                }
                Button(String(localized: "Refresh", comment: "Button")) {
                    receipt = CostSample.current().map(CostReceipt.init(sample:))
                }
            } header: {
                Text(String(localized: "What \(Branding.appName) costs your Mac", comment: "Settings section"))
            } footer: {
                Text(String(localized: "Read straight from the kernel. The same numbers appear at the bottom of the open panel.", comment: "Cost footer"))
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section {
                ForEach(PermissionService.automationTargets) { target in
                    LabeledContent(String(localized: "Control \(target.name)", comment: "Permission row"),
                                   value: Self.describe(permissions.automation[target.bundleID] ?? .unknown))
                }
                Button(String(localized: "Open Automation settings", comment: "Button")) {
                    PermissionService.openAutomationSettings()
                }
            } header: {
                Text(String(localized: "Permissions", comment: "Settings section"))
            } footer: {
                Text(String(localized: "\(Branding.appName) needs no permissions to run. Automation is only asked for if you use playback controls without the Now Playing helper.", comment: "Permissions footer"))
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section {
                Toggle(String(localized: "Show debug overlay in the panel", comment: "Setting"), isOn: $preferences.debugOverlay)
                Button(String(localized: "Show data folder in Finder", comment: "Button")) {
                    NSWorkspace.shared.activateFileViewerSelecting([Branding.supportDirectory])
                }
            } header: {
                Text(String(localized: "Diagnostics", comment: "Settings section"))
            }
        }
        .formStyle(.grouped)
    }

    private static func describe(_ status: PermissionService.AutomationStatus) -> String {
        switch status {
        case .granted: return String(localized: "Allowed", comment: "Permission status")
        case .denied: return String(localized: "Not allowed", comment: "Permission status")
        case .notAsked: return String(localized: "Not asked yet", comment: "Permission status")
        case .appNotRunning: return String(localized: "App not running", comment: "Permission status")
        case .unknown: return String(localized: "Unknown", comment: "Permission status")
        }
    }
}

// MARK: - About

private struct AboutTab: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "rectangle.topthird.inset.filled")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(.primary)
            Text(Branding.appName)
                .font(.system(size: 22, weight: .semibold))
                .tracking(-0.4)
            Text(verbatim: Branding.version)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
            Text(String(localized: "The notch app that disappears.", comment: "Tagline"))
                .font(.body)
            Divider().padding(.horizontal, 60)
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "Acknowledgements", comment: "About section"))
                    .font(.headline)
                Text(verbatim: "mediaremote-adapter — Copyright (c) 2025, Jonas van den Berg and contributors. BSD 3-Clause License.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let license = Self.adapterLicense {
                    ScrollView {
                        Text(verbatim: license)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 110)
                }
            }
            .padding(.horizontal, 40)
            Spacer(minLength: 0)
        }
        .padding(.top, 24)
    }

    private static var adapterLicense: String? {
        guard let url = Bundle.main.url(forResource: "mediaremote-adapter-LICENSE", withExtension: "txt") else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }
}
