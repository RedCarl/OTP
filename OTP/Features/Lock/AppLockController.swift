import Foundation
import LocalAuthentication
import Observation
import SwiftUI

@MainActor
@Observable
final class AppLockController {
    private(set) var isLocked = false
    private(set) var isAuthenticating = false

    private var backgroundedAt: Date?
    private var didPrepareLaunch = false

    init() {
        guard !AppConfiguration.isAutomatedRun else { return }
        let defaults = UserDefaults.standard
        let enabled = defaults.object(forKey: "appLockEnabled") as? Bool ?? false
        let onboarded = defaults.bool(forKey: "hasCompletedOnboarding")
        isLocked = enabled && onboarded
        didPrepareLaunch = true
    }

    static var canAuthenticate: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    /// Cached: creating an `LAContext` is not free and both accessors are read
    /// from view bodies (lock screen, settings). The biometry type cannot change
    /// while the app is running.
    private static let biometryType: LABiometryType = {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
        return context.biometryType
    }()

    static var methodName: String {
        switch biometryType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        default:
            return L10n.t("iPhone 密码")
        }
    }

    static var methodIcon: String {
        switch biometryType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        case .opticID:
            return "opticid"
        default:
            return "lock.fill"
        }
    }

    /// Shared authentication used both for unlocking and for enabling the feature.
    static func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = L10n.t("取消")
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return false
        }
        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
        } catch {
            return false
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
        guard isLocked, !isAuthenticating else { return }
        isAuthenticating = true

        let context = LAContext()
        context.localizedCancelTitle = L10n.t("取消")
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // No biometrics / passcode configured: never trap the user.
            isAuthenticating = false
            withAnimation(.easeOut(duration: 0.3)) { isLocked = false }
            return
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: L10n.t("解锁 OTP 令牌")
            )
            if success {
                // The system Face ID sheet is still dismissing here. Keep the
                // cover for a beat, then fade it once the sheet is gone.
                try? await Task.sleep(for: .milliseconds(550))
                withAnimation(.easeOut(duration: 0.45)) { isLocked = false }
                try? await Task.sleep(for: .milliseconds(400))
                isAuthenticating = false
                return
            }
        } catch {
            // Cancelled or failed: keep the lock screen visible.
        }

        isAuthenticating = false
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
                withAnimation(.easeIn(duration: 0.28)) { isLocked = true }
            }
            backgroundedAt = nil
        default:
            break
        }
    }
}