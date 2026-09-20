import CoreGraphics
import Services

/// One display's inputs to the eligibility rules, lifted out of `NSScreen` so the rules can be
/// exercised without hardware. Most of the display matrix in `docs/04-QA-CHECKLIST.md` is this
/// type plus `NotchGeometry`, so both are pure value types with no AppKit in their signatures.
public struct DisplayCandidate: Equatable, Sendable {
    public let id: CGDirectDisplayID
    /// Stable across reboots. Resolved only in `.chosen` mode, where it is the matching key.
    public let uuid: String?
    public let isBuiltIn: Bool

    public init(id: CGDirectDisplayID, uuid: String?, isBuiltIn: Bool) {
        self.id = id
        self.uuid = uuid
        self.isBuiltIn = isBuiltIn
    }
}

/// Decides which displays should carry a panel, before fullscreen apps are subtracted.
public enum DisplayEligibility {
    /// - Parameters:
    ///   - candidates: in `NSScreen.screens` order. The first entry is the menu-bar display, which
    ///     is the fallback whenever a mode would otherwise select nothing.
    /// - Returns: the eligible displays, in the order given.
    public static func eligible(
        among candidates: [DisplayCandidate],
        mode: DisplayMode,
        chosenUUIDs: Set<String>
    ) -> [DisplayCandidate] {
        guard !candidates.isEmpty else { return [] }
        switch mode {
        case .all:
            return candidates
        case .builtInOnly:
            let builtIn = candidates.filter(\.isBuiltIn)
            // Clamshell mode: no built-in display is active. Fall back to the menu-bar display
            // rather than silently showing nothing — "doesn't work on my monitor" is the complaint
            // this product exists to fix.
            return builtIn.isEmpty ? Array(candidates.prefix(1)) : builtIn
        case .chosen:
            let picked = candidates.filter { candidate in
                guard let uuid = candidate.uuid else { return false }
                return chosenUUIDs.contains(uuid)
            }
            // Every chosen display is unplugged: same reasoning as clamshell.
            return picked.isEmpty ? Array(candidates.prefix(1)) : picked
        }
    }
}
