import Combine
import CoreGraphics
import Services
import SwiftUI

/// Per-display view state. Owned by `NotchPanelController`, observed by `NotchRootView`.
@MainActor
final class PanelModel: ObservableObject {
    let displayID: CGDirectDisplayID
    @Published var geometry: NotchGeometry
    @Published var phase: NotchPhase = .closed
    @Published var peek: PeekContent?
    /// 0…1: how strongly the notch is being pulled by a nearby file drag.
    @Published var magnetStrength: CGFloat = 0
    /// Horizontal lean toward the dragged file, in points.
    @Published var magnetLean: CGFloat = 0
    @Published var isDropTargeted = false
    @Published var receipt: CostReceipt?

    var onClick: () -> Void = {}
    var onCollapse: () -> Void = {}

    init(displayID: CGDirectDisplayID, geometry: NotchGeometry) {
        self.displayID = displayID
        self.geometry = geometry
    }
}

private struct DropTargetedKey: EnvironmentKey {
    static let defaultValue = false
}

public extension EnvironmentValues {
    /// True while a file is being dragged over the open panel. Read by the shelf to highlight.
    var notchDropTargeted: Bool {
        get { self[DropTargetedKey.self] }
        set { self[DropTargetedKey.self] = newValue }
    }
}
