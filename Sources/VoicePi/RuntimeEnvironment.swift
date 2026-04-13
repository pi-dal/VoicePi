import Foundation

enum RuntimeEnvironment {
    static var isRunningTests: Bool {
        let environment = ProcessInfo.processInfo.environment
        if environment["XCTestConfigurationFilePath"] != nil {
            return true
        }
        if environment["XCTestSessionIdentifier"] != nil {
            return true
        }
        return ProcessInfo.processInfo.processName.lowercased().contains("xctest")
    }
}
