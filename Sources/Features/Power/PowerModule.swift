import Combine
import DesignSystem
import NotchCore
import Services
import SwiftUI

@MainActor
public final class PowerModule: NotchModule {
    public let id = "power"
    public let symbolName = "battery.75percent"
    public var title: String { String(localized: "Battery", comment: "Module name") }
    /// Desktop Macs have no battery; the module simply doesn't exist there.
    public var isEnabled: Bool { preferences.powerEnabled && hasBattery }

    private let preferences: Preferences
    private let monitor = PowerMonitor()
    private let hasBattery = PowerMonitor.hasBattery
    private weak var host: NotchHost?
    private var cancellables: Set<AnyCancellable> = []
    private var lastWingKey: String?

    public init(preferences: Preferences) {
        self.preferences = preferences
    }

    public func makeExpandedView() -> AnyView {
        AnyView(BatteryView(monitor: monitor))
    }

    public func makeHeaderAccessory() -> AnyView? {
        AnyView(BatteryBadge(monitor: monitor))
    }

    public func activate(host: NotchHost) {
        self.host = host
        monitor.onPowerSourceChange = { [weak self] snapshot in self?.peek(snapshot) }
        monitor.start()
        monitor.$snapshot
            .combineLatest(preferences.$showBatteryWhenCollapsed)
            .sink { [weak self] snapshot, show in self?.updateWings(snapshot: snapshot, show: show) }
            .store(in: &cancellables)
    }

    public func deactivate() {
        cancellables.removeAll()
        monitor.onPowerSourceChange = nil
        monitor.stop()
        host?.setWings(nil, from: id)
        lastWingKey = nil
        host = nil
    }

    public func panelDidOpen() {
        monitor.refreshHealth()
    }

    private func updateWings(snapshot: PowerSnapshot?, show: Bool) {
        let key = show ? snapshot.map { "\($0.percent)|\($0.symbolName)" } : nil
        guard key != lastWingKey else { return }
        lastWingKey = key
        guard show, let snapshot else {
            host?.setWings(nil, from: id)
            return
        }
        host?.setWings(
            WingContent(
                priority: 5,
                width: Metrics.wingWidth,
                leading: AnyView(BatteryGlyph(snapshot: snapshot)),
                trailing: AnyView(PercentText(percent: snapshot.percent))
            ),
            from: id
        )
    }

    /// A short peek when the charger is connected or disconnected — never on percentage changes.
    private func peek(_ snapshot: PowerSnapshot) {
        let charging = snapshot.isOnAC
        host?.requestPeek(PeekContent(
            width: 74,
            leading: AnyView(
                HStack {
                    Spacer(minLength: 0)
                    Image(systemName: charging ? "bolt.fill" : "powerplug")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(charging ? Palette.positive : Palette.secondary)
                        .padding(.trailing, 12)
                }
            ),
            trailing: AnyView(
                HStack {
                    PercentText(percent: snapshot.percent)
                        .padding(.leading, 12)
                    Spacer(minLength: 0)
                }
            )
        ))
    }
}
