import Foundation
import Observation

@MainActor
@Observable
final class TokenListModel {
    private let store: TokenStore
    private var tickerTask: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?

    private(set) var tokens: [OTPToken] = []
    private(set) var codes: [UUID: String] = [:]
    private(set) var skippedCount = 0
    private(set) var now = Date()
    private(set) var isLoading = false
    private(set) var copiedTokenID: UUID?
    private(set) var copySignal = 0

    var searchText = ""
    var errorMessage: String?
    var toastMessage: String?

    init(store: TokenStore? = nil) {
        self.store = store ?? TokenStore(
            repository: KeychainTokenRepository(service: AppConfiguration.repositoryServiceName)
        )
    }

    // MARK: - Derived state

    var filteredTokens: [OTPToken] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return tokens }
        return tokens.filter { $0.searchText.contains(query) }
    }

    func code(for token: OTPToken) -> String? {
        codes[token.id]
    }

    func remaining(for token: OTPToken) -> Int {
        TOTP.remaining(at: now, period: token.period)
    }

    func progress(for token: OTPToken) -> Double {
        TOTP.progress(at: now, period: token.period)
    }

    // MARK: - Lifecycle

    func start() async {
        await refresh()
        startTicker()
    }

    func startTicker() {
        guard tickerTask == nil else { return }
        tickerTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.tick()
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }

    func stopTicker() {
        tickerTask?.cancel()
        tickerTask = nil
    }

    private func tick() {
        now = Date()
        recomputeCodes()
    }

    // MARK: - Loading

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await store.load()
            tokens = Self.sorted(result.tokens)
            skippedCount = result.skippedCount
            recomputeCodes()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func recomputeCodes() {
        var refreshed: [UUID: String] = [:]
        refreshed.reserveCapacity(tokens.count)
        for token in tokens {
            switch token.kind {
            case .totp:
                refreshed[token.id] = TOTP.code(
                    secret: token.secret,
                    at: now,
                    period: token.period,
                    digits: token.digits,
                    algorithm: token.algorithm
                )
            case .hotp:
                if let existing = codes[token.id] {
                    refreshed[token.id] = existing
                }
            }
        }
        if refreshed != codes {
            codes = refreshed
        }
    }

    static func sorted(_ tokens: [OTPToken]) -> [OTPToken] {
        tokens.sorted { lhs, rhs in
            if lhs.pinned != rhs.pinned { return lhs.pinned }
            let issuerOrder = lhs.displayIssuer.localizedStandardCompare(rhs.displayIssuer)
            if issuerOrder != .orderedSame { return issuerOrder == .orderedAscending }
            return lhs.displayAccount.localizedStandardCompare(rhs.displayAccount) == .orderedAscending
        }
    }

    // MARK: - Mutations

    @discardableResult
    func save(_ token: OTPToken) async -> Bool {
        do {
            let validated = try token.validated()
            try await store.save(validated)
            await refresh()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func delete(_ token: OTPToken) async {
        do {
            try await store.delete(id: token.id)
            await refresh()
            showToast("已删除 \(token.displayIssuer)")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteAll() async {
        do {
            try await store.deleteAll()
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Imports a batch with a single refresh; returns how many were written.
    @discardableResult
    func importTokens(_ tokens: [OTPToken]) async -> Int {
        var imported = 0
        do {
            for token in tokens {
                let validated = try token.validated()
                try await store.save(validated)
                imported += 1
            }
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
        return imported
    }

    func isDuplicate(_ token: OTPToken) -> Bool {
        let issuer = token.issuer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let account = token.accountName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return tokens.contains { existing in
            existing.secret == token.secret
                && existing.issuer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == issuer
                && existing.accountName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == account
        }
    }

    func togglePin(_ token: OTPToken) async {
        var copy = token
        copy.pinned.toggle()
        copy.updatedAt = Date()
        await save(copy)
    }

    // MARK: - Codes

    func copyCode(for token: OTPToken) async {
        switch token.kind {
        case .totp:
            guard let code = codes[token.id] ?? TOTP.code(
                secret: token.secret,
                at: Date(),
                period: token.period,
                digits: token.digits,
                algorithm: token.algorithm
            ) as String? else { return }
            deliver(code, for: token)
        case .hotp:
            await generateHOTP(for: token)
        }
    }

    private func deliver(_ code: String, for token: OTPToken) {
        Clipboard.copy(code)
        copiedTokenID = token.id
        copySignal += 1
        showToast("已复制 · 30 秒后自动清除剪贴板")
    }

    private func generateHOTP(for token: OTPToken) async {
        let code = HOTP.code(
            secret: token.secret,
            counter: token.counter,
            digits: token.digits,
            algorithm: token.algorithm
        )
        guard !code.isEmpty else { return }
        codes[token.id] = code
        Clipboard.copy(code)
        copiedTokenID = token.id
        copySignal += 1
        showToast("已生成并复制 \(OTPCodeFormatter.grouped(code))")

        var advanced = token
        advanced.counter = token.counter &+ 1
        advanced.updatedAt = Date()
        do {
            try await store.save(advanced)
            if let index = tokens.firstIndex(where: { $0.id == token.id }) {
                tokens[index] = advanced
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    #if DEBUG
    /// Seeds a few sample tokens for screenshot runs (-seedDemo launch argument).
    func seedDemoTokensIfEmpty() async {
        guard tokens.isEmpty else { return }
        let samples: [OTPToken] = [
            OTPToken(issuer: "GitHub", accountName: "alice@example.com", secret: Base32.decode("JBSWY3DPEHPK3PXP") ?? Data()),
            OTPToken(issuer: "Google", accountName: "alice@gmail.com", secret: Base32.decode("GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ") ?? Data(), pinned: true),
            OTPToken(issuer: "AWS", accountName: "admin", secret: Base32.decode("MFRGGZDFMZTWQ2LKNNWG23TP") ?? Data(), kind: .hotp, digits: 6),
        ]
        for sample in samples {
            try? await store.save(sample)
        }
        await refresh()
    }
    #endif

    // MARK: - Toast

    func showToast(_ message: String) {
        toastMessage = message
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            guard !Task.isCancelled else { return }
            self?.toastMessage = nil
        }
    }
}