import AppKit
import Combine
import Services
import SwiftUI

public struct ModuleRef: Identifiable {
    public let id: String
    public let module: any NotchModule
}

/// Shared state for every panel on every display: which modules exist, which tab is selected,
/// and what the collapsed wings show. One instance per app.
@MainActor
public final class NotchHub: ObservableObject, NotchHost {
    @Published public private(set) var modules: [any NotchModule] = []
    @Published public private(set) var enabledModuleIDs: [String] = []
    @Published public var selectedModuleID: String?
    @Published public private(set) var wings: WingContent?

    /// Wired by `NotchWindowManager`.
    var peekHandler: ((PeekContent) -> Void)?
    var collapseHandler: (() -> Void)?
    var selectionHandler: (() -> Void)?
    var wingsHandler: (() -> Void)?

    /// Wired by the app delegate.
    public var openSettings: (() -> Void)?

    private var wingsByModule: [String: WingContent] = [:]
    private var activeModuleIDs: Set<String> = []

    public init() {}

    public var enabledModules: [any NotchModule] {
        modules.filter { enabledModuleIDs.contains($0.id) }
    }

    /// Identifiable wrappers for `ForEach`.
    public var enabledModuleRefs: [ModuleRef] {
        enabledModules.map { ModuleRef(id: $0.id, module: $0) }
    }

    public var selectedModule: (any NotchModule)? {
        enabledModules.first { $0.id == selectedModuleID } ?? enabledModules.first
    }

    public var dropModule: (any NotchModule)? {
        enabledModules.first { $0 is any DropAcceptingModule }
    }

    public func register(_ module: any NotchModule) {
        modules.append(module)
        refreshModules()
    }

    /// Activates newly enabled modules and fully deactivates disabled ones. Idempotent.
    public func refreshModules() {
        for module in modules {
            let active = activeModuleIDs.contains(module.id)
            if module.isEnabled, !active {
                activeModuleIDs.insert(module.id)
                module.activate(host: self)
                Log.app.info("Module \(module.id, privacy: .public) activated")
            } else if !module.isEnabled, active {
                activeModuleIDs.remove(module.id)
                module.deactivate()
                setWings(nil, from: module.id)
                Log.app.info("Module \(module.id, privacy: .public) deactivated")
            }
        }
        enabledModuleIDs = modules.filter { $0.isEnabled }.map { $0.id }
        if let selected = selectedModuleID, !enabledModuleIDs.contains(selected) {
            selectedModuleID = enabledModuleIDs.first
        } else if selectedModuleID == nil {
            selectedModuleID = enabledModuleIDs.first
        }
    }

    public func deactivateAll() {
        for module in modules where activeModuleIDs.contains(module.id) {
            module.deactivate()
        }
        activeModuleIDs.removeAll()
    }

    func panelDidOpen() {
        selectedModule?.panelDidOpen()
    }

    func handleDrop(_ pasteboard: NSPasteboard) -> Bool {
        guard let module = dropModule else { return false }
        selectedModuleID = module.id
        return module.handleDrop(pasteboard)
    }

    func selectDropModule() {
        guard let module = dropModule, selectedModuleID != module.id else { return }
        selectedModuleID = module.id
        selectionHandler?()
    }

    // MARK: NotchHost

    public func setWings(_ wings: WingContent?, from moduleID: String) {
        if let wings {
            wingsByModule[moduleID] = wings
        } else {
            wingsByModule.removeValue(forKey: moduleID)
        }
        let winner = wingsByModule.values.max { $0.priority < $1.priority }
        let changed = (winner == nil) != (self.wings == nil) || winner?.width != self.wings?.width
        self.wings = winner
        if changed { wingsHandler?() }
    }

    public func requestPeek(_ peek: PeekContent) {
        peekHandler?(peek)
    }

    public func requestCollapse() {
        collapseHandler?()
    }

    public func select(moduleID: String) {
        guard enabledModuleIDs.contains(moduleID) else { return }
        selectedModuleID = moduleID
        selectionHandler?()
    }
}
