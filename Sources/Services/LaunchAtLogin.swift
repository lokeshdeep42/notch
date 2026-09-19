import Foundation
import ServiceManagement

/// Launch at login via `SMAppService`, reporting the *real* status — including "needs approval in
/// System Settings" — instead of a toggle that silently does nothing (a named competitor complaint).
@MainActor
public final class LaunchAtLogin: ObservableObject {
    public enum Status: Equatable {
        case enabled
        case disabled
        case requiresApproval
        case failed(String)
    }

    @Published public private(set) var status: Status = .disabled

    public init() {
        refresh()
    }

    public var isOn: Bool {
        status == .enabled || status == .requiresApproval
    }

    public func refresh() {
        switch SMAppService.mainApp.status {
        case .enabled: status = .enabled
        case .requiresApproval: status = .requiresApproval
        case .notRegistered, .notFound: status = .disabled
        @unknown default: status = .disabled
        }
    }

    public func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            refresh()
        } catch {
            Log.settings.error("Launch at login change failed: \(error.localizedDescription, privacy: .public)")
            refresh()
            if status != .requiresApproval {
                status = .failed(error.localizedDescription)
            }
        }
    }

    public func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
