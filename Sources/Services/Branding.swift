import Foundation

/// The product name lives here and nowhere else. Renaming the app is a change to this file
/// plus the bundle identifier in `App/Info.plist`.
public enum Branding {
    public static let appName = "Sill"
    public static let bundleID = "app.sill.Sill"
    public static let helpURL = URL(string: "https://github.com/lokeshdeep42/notch#readme")
        ?? URL(fileURLWithPath: "/")

    /// `~/Library/Application Support/<bundle id>/`, created on first access.
    public static var supportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        let url = base.appendingPathComponent(bundleID, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    public static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "dev"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "\(short) (\(build))"
    }
}
