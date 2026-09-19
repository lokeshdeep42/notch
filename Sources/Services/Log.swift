import os

/// One `Logger` per subsystem area. Filter in Console.app with `subsystem:app.sill.Sill`.
public enum Log {
    public static let app = Logger(subsystem: Branding.bundleID, category: "app")
    public static let notch = Logger(subsystem: Branding.bundleID, category: "notch")
    public static let hover = Logger(subsystem: Branding.bundleID, category: "hover")
    public static let display = Logger(subsystem: Branding.bundleID, category: "display")
    public static let media = Logger(subsystem: Branding.bundleID, category: "media")
    public static let shelf = Logger(subsystem: Branding.bundleID, category: "shelf")
    public static let clipboard = Logger(subsystem: Branding.bundleID, category: "clipboard")
    public static let power = Logger(subsystem: Branding.bundleID, category: "power")
    public static let settings = Logger(subsystem: Branding.bundleID, category: "settings")
}
