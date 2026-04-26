import Foundation

enum RuntimeEnvironment {
    static var isRunningTests: Bool {
        let processInfo = ProcessInfo.processInfo
        let lowercasedProcessName = processInfo.processName.lowercased()
        if lowercasedProcessName.contains("xctest") {
            return true
        }
        if processInfo.arguments.contains(where: {
            let argument = $0.lowercased()
            return argument.contains("xctest") || argument.hasSuffix(".xctest")
        }) {
            return true
        }
        if Bundle.main.bundlePath.lowercased().hasSuffix(".xctest") {
            return true
        }
        if Bundle.allBundles.contains(where: { $0.bundlePath.hasSuffix(".xctest") }) {
            return true
        }
        let environment = processInfo.environment
        return environment["XCTestConfigurationFilePath"] != nil
            || environment["XCTestBundlePath"] != nil
            || environment["SWIFT_TESTING_ENABLED"] == "1"
            || NSClassFromString("XCTestCase") != nil
            || NSClassFromString("XCTest") != nil
    }
}
