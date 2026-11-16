import Foundation
import LocalAuthentication
import Observation
import SwiftUI

@MainActor
@Observable
final class AppLockController {
    private(set) var isLocked = false

    private var backgroundedAt: Date?
    private var didPrepareLaunch = false

    static var canAuthenticate: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    static var methodName: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
        switch context.biometryType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        default:
            return "iPhone 密码"
        }
    }

    static var methodIcon: String {
        switch methodName {
        case "Face ID":
            return "faceid"
        case "Touch ID":
            return "touchid"
        case "Optic ID":
            return "opticid"
        default:
            return "lock.fill"
        }
    }

    var isEnabled: Bool {
        if AppConfiguration.isAutomatedRun { return false }
        return UserDefaults.standard.object(forKey: "appLockEnabled") as? Bool ?? false
    }

    /// Locks on cold launch only once onboarding is done and the user opted in.
    func prepareForLaunch(allowLock: Bool) {
        guard !didPrepareLaunch else { return }
        didPrepareLaunch = true
        isLocked = allowLock && isEnabled
    }

    func unlock() async {
        guard isLocked else { return }
        let context = LAContext()
        context.localizedCancelTitle = "取消"
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // No biometrics / passcode configured: never trap the user.
            isLocked = false
            return
        }
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "解锁 OTP 令牌"
            )
            if success { isLocked = false }
        } catch {
            // Cancelled or failed: keep the lock screen visible.
        }
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .background:
            backgroundedAt = Date()
        case .active:
            guard isEnabled else {
                isLocked = false
                backgroundedAt = nil
                return
            }
            if let backgroundedAt, Date().timeIntervalSince(backgroundedAt) > 60 {
                isLocked = true
            }
            backgroundedAt = nil
        default:
            break
        }
    }
}
