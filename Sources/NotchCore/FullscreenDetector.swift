import AppKit
import CoreGraphics

/// Finds displays currently owned by a fullscreen app, without Accessibility or Screen Recording.
/// Window *bounds, layer and owner* are readable without permission; only titles need Screen
/// Recording, and we never read titles.
///
/// Called only in response to space/app-activation notifications — never on a timer.
enum FullscreenDetector {
    static func fullscreenDisplayIDs(among displays: [CGDirectDisplayID]) -> Set<CGDirectDisplayID> {
        guard !displays.isEmpty,
              let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]]
        else { return [] }

        let ownPID = ProcessInfo.processInfo.processIdentifier
        let displayBounds = displays.map { ($0, CGDisplayBounds($0)) }
        var result: Set<CGDirectDisplayID> = []

        for window in info {
            guard let layer = window[kCGWindowLayer as String] as? Int, layer == 0,
                  let pid = window[kCGWindowOwnerPID as String] as? Int32, pid != ownPID,
                  let boundsDict = window[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary)
            else { continue }

            for (id, display) in displayBounds where covers(bounds, display) {
                result.insert(id)
            }
        }
        return result
    }

    /// A window covering the whole display — including the menu-bar strip — is fullscreen.
    /// Maximised ("zoomed") windows stop below the menu bar, so they don't match.
    static func covers(_ window: CGRect, _ display: CGRect) -> Bool {
        abs(window.minX - display.minX) <= 1
            && abs(window.minY - display.minY) <= 1
            && window.width >= display.width - 1
            && window.height >= display.height - 1
    }
}
