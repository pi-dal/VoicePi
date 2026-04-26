import AppKit
import Foundation

struct PromptDestinationContext: Equatable {
    let appBundleID: String?
    let websiteHost: String?

    init(
        appBundleID: String? = nil,
        websiteHost: String? = nil,
        websiteURL: URL? = nil
    ) {
        self.appBundleID = Self.normalizedAppBundleID(appBundleID)
        self.websiteHost = Self.normalizedWebsiteHost(websiteHost) ?? Self.normalizedWebsiteHost(
            websiteURL?.absoluteString
        )
    }

    static func normalizedAppBundleID(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    static func normalizedWebsiteHost(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), let host = normalizedHost(from: url) {
            return host
        }

        if let url = URL(string: "https://\(trimmed)"), let host = normalizedHost(from: url) {
            return host
        }

        return trimmed
            .split(separator: "/")
            .first
            .map(String.init)?
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
    }

    private static func normalizedHost(from url: URL) -> String? {
        let host = url.host?.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased() ?? ""
        return host.isEmpty ? nil : host
    }
}

protocol BrowserURLReading {
    func currentURL(for bundleID: String) -> URL?
}

struct AppleScriptBrowserURLReader: BrowserURLReading {
    func currentURL(for bundleID: String) -> URL? {
        guard let style = BrowserScriptStyle(bundleID: bundleID) else { return nil }

        let source: String
        switch style {
        case .safari:
            source = #"tell application id "\#(bundleID)" to return URL of front document"#
        case .chromium:
            source = #"tell application id "\#(bundleID)" to return URL of active tab of front window"#
        }

        var error: NSDictionary?
        guard
            let script = NSAppleScript(source: source),
            let result = script.executeAndReturnError(&error).stringValue,
            error == nil
        else {
            return nil
        }

        let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : URL(string: trimmed)
    }

    private enum BrowserScriptStyle {
        case safari
        case chromium

        init?(bundleID: String) {
            switch PromptDestinationContext.normalizedAppBundleID(bundleID) {
            case "com.apple.safari", "com.apple.safaritechnologypreview":
                self = .safari
            case
                "com.google.chrome",
                "com.google.chrome.canary",
                "org.chromium.chromium",
                "com.brave.browser",
                "com.microsoft.edgemac",
                "company.thebrowser.browser",
                "com.vivaldi.vivaldi":
                self = .chromium
            default:
                return nil
            }
        }
    }
}

struct PromptDestinationInspector {
    var workspace: NSWorkspace
    var browserURLReader: BrowserURLReading

    init(
        workspace: NSWorkspace = .shared,
        browserURLReader: BrowserURLReading = AppleScriptBrowserURLReader()
    ) {
        self.workspace = workspace
        self.browserURLReader = browserURLReader
    }

    func currentDestinationContext() -> PromptDestinationContext {
        let rawBundleID = workspace.frontmostApplication?.bundleIdentifier
        let bundleID = PromptDestinationContext.normalizedAppBundleID(rawBundleID)
        let websiteURL = rawBundleID.flatMap { browserURLReader.currentURL(for: $0) }

        return PromptDestinationContext(
            appBundleID: bundleID,
            websiteURL: websiteURL
        )
    }
}
