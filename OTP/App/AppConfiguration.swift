import Foundation

/// Launch-argument overrides used by UI tests and screenshot runs. Debug builds
/// only; release builds always use the production keychain service.
enum AppConfiguration {
    #if DEBUG
    static var repositoryServiceName: String {
        value(for: "-uiTestService") ?? value(for: "-demoService") ?? KeychainTokenRepository.defaultService
    }

    static var shouldSeedDemoTokens: Bool {
        ProcessInfo.processInfo.arguments.contains("-seedDemo")
    }

    /// UI tests and screenshot runs must not be blocked by lock/onboarding.
    static var isAutomatedRun: Bool {
        ProcessInfo.processInfo.arguments.contains("-uiTestService")
            || ProcessInfo.processInfo.arguments.contains("-seedDemo")
            || ProcessInfo.processInfo.arguments.contains("-demoService")
    }

    private static func value(for flag: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }
    #else
    static let repositoryServiceName = KeychainTokenRepository.defaultService
    static let shouldSeedDemoTokens = false
    static let isAutomatedRun = false
    #endif
}