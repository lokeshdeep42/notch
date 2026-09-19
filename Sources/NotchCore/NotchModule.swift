import AppKit
import SwiftUI

/// Static content shown beside the hardware notch while collapsed (e.g. artwork + play state).
/// Must not animate per frame: collapsed rendering has to cost nothing.
public struct WingContent {
    public let priority: Int
    public let width: CGFloat
    public let leading: AnyView
    public let trailing: AnyView

    public init(priority: Int, width: CGFloat, leading: AnyView, trailing: AnyView) {
        self.priority = priority
        self.width = width
        self.leading = leading
        self.trailing = trailing
    }
}

/// A brief, self-dismissing notification that grows out of the notch (track change, charger).
public struct PeekContent: Identifiable {
    public let id = UUID()
    public let width: CGFloat
    public let duration: TimeInterval
    public let leading: AnyView
    public let trailing: AnyView

    public init(width: CGFloat, duration: TimeInterval = 2.4, leading: AnyView, trailing: AnyView) {
        self.width = width
        self.duration = duration
        self.leading = leading
        self.trailing = trailing
    }
}

/// What a feature can ask of the notch. Implemented by `NotchHub`.
@MainActor
public protocol NotchHost: AnyObject {
    func setWings(_ wings: WingContent?, from moduleID: String)
    func requestPeek(_ peek: PeekContent)
    func requestCollapse()
    func select(moduleID: String)
}

/// A feature that lives in the panel. `NotchCore` knows only this protocol — never a concrete
/// feature — which is what keeps feature modules independent of each other.
@MainActor
public protocol NotchModule: AnyObject {
    var id: String { get }
    var title: String { get }
    var symbolName: String { get }
    /// Whether the user has this module switched on. Disabled modules are fully deactivated.
    var isEnabled: Bool { get }
    /// The panel becomes key (accepts typing) while this module is showing.
    var wantsKeyboardFocus: Bool { get }

    func makeExpandedView() -> AnyView
    /// Small view in the top-right of the open panel (e.g. battery). Nil for none.
    func makeHeaderAccessory() -> AnyView?

    /// Start observing. Called when the module becomes enabled.
    func activate(host: NotchHost)
    /// Stop every timer, observer and helper process. Called when disabled and on quit.
    func deactivate()
    /// The panel just opened: a chance to refresh anything read on demand.
    func panelDidOpen()

    /// Handles files, images or text dropped on the notch. Return false if not handled.
    func handleDrop(_ pasteboard: NSPasteboard) -> Bool
}

public extension NotchModule {
    var wantsKeyboardFocus: Bool { false }
    func makeHeaderAccessory() -> AnyView? { nil }
    func panelDidOpen() {}
    func handleDrop(_ pasteboard: NSPasteboard) -> Bool { false }
}

/// A module that accepts drops (the shelf). The panel opens to it when a file is dragged near.
@MainActor
public protocol DropAcceptingModule: NotchModule {}
