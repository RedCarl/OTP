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
    private(set) var isLoading = false
    private(set) var lastRefreshedAt: Date?
    private(set) var copySignal = 0

    var searchText = ""
    var errorMessage: String?
    var toastMessage: String?

    /// Last TOTP window each token was ticked for. Observation-ignored: this is
    /// bookkeeping, not view state, and writing it must not invalidate views.
    @ObservationIgnored private var windowIndex: [UUID: UInt64] = [:]
    /// Pre-lowered search haystacks, so filtering does not rebuild strings for
    /// every token on every keystroke.
    @ObservationIgnored private var searchHaystacks: [UUID: String] = [:]

    init(store: TokenStore? = nil) {
        self.store = store ?? TokenStore(
            repository: KeychainTokenRepository(service: AppConfiguration.repositoryServiceName)
        )
    }

    // MARK: - Derived state

    var filteredTokens: [OTPToken] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return tokens }
        return tokens.filter { token in
            let haystack = searchHaystacks[token.id] ?? token.searchText
            return haystack.contains(query)
        }
    }

    func code(for token: OTPToken) -> String? {
        codes[token.id]
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
                let delay = self.delayUntilNextWindowBoundary()
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }

    /// Sleeps until the next TOTP window boundary instead of polling, so the
    /// app wakes roughly once per period instead of four times a second.
    private func delayUntilNextWindowBoundary() -> TimeInterval {
        let instant = Date().timeIntervalSince1970
        var shortest: TimeInterval?
        for token in tokens where token.kind == .totp {
            let period = Double(max(1, token.period))
            let remaining = period - instant.truncatingRemainder(dividingBy: period)
            if remaining < (shortest ?? .greatestFiniteMagnitude) {
                shortest = remaining
            }
        }
        // No time-based tokens: nothing to refresh until the set changes.
        guard let shortest else { return 60 }
        // Wake just past the boundary; never spin.
        return min(max(shortest + 0.05, 0.1), 60)
    }

    /// The ticker sleeps for the shortest period it knew about; after the token
    /// set changes, wake it so a newly added token is not stale for a whole
    /// sleeping window.
    private func rescheduleTicker() {
        guard tickerTask != nil else { return }
        tickerTask?.cancel()
        tickerTask = nil
        startTicker()
    }

    func stopTicker() {
        tickerTask?.cancel()
        tickerTask = nil
    }

    /// Polls a few times per second but only publishes `codes` when a token's
    /// TOTP window actually rolls over. The per-row countdown keeps its own
    /// clock (see `TokenRowView`), so publishing a fresh `now` here would only
    /// re-render the whole list twice a second for values that did not change.
    private func tick() {
        refreshCodesIfWindowChanged()
    }

    // MARK: - Loading

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await store.load()
            tokens = Self.sorted(result.tokens)
            skippedCount = result.skippedCount
            lastRefreshedAt = Date()
            rebuildSearchIndex()
            recomputeCodes()
            rescheduleTicker()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Indexes the lowercased issuer/account of every token once per load, and
    /// drops bookkeeping for tokens that no longer exist.
    private func rebuildSearchIndex() {
        var index: [UUID: String] = [:]
        index.reserveCapacity(tokens.count)
        for token in tokens {
            index[token.id] = token.searchText
        }
        searchHaystacks = index
        let liveIDs = Set(index.keys)
        windowIndex = windowIndex.filter { liveIDs.contains($0.key) }
    }

    /// Full recompute, used after loads and mutations.
    private func recomputeCodes() {
        let instant = Date()
        var refreshed: [UUID: String] = [:]
        refreshed.reserveCapacity(tokens.count)
        for token in tokens {
            switch token.kind {
            case .totp:
                windowIndex[token.id] = TOTP.counter(at: instant, period: token.period)
                refreshed[token.id] = TOTP.code(
                    secret: token.secret,
                    at: instant,
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

    /// Recomputes only the tokens whose window rolled over since the last tick.
    private func refreshCodesIfWindowChanged() {
        guard !tokens.isEmpty else { return }
        let instant = Date()
        var refreshed = codes
        var changed = false
        for token in tokens where token.kind == .totp {
            let window = TOTP.counter(at: instant, period: token.period)
            guard windowIndex[token.id] != window || codes[token.id] == nil else { continue }
            windowIndex[token.id] = window
            refreshed[token.id] = TOTP.code(
                secret: token.secret,
                at: instant,
                period: token.period,
                digits: token.digits,
                algorithm: token.algorithm
            )
            changed = true
        }
        if changed, refreshed != codes {
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
            showToast(L10n.format("已删除 %@", token.displayIssuer))
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

    func restore(_ tokens: [OTPToken], mode: RestoreMode) async -> RestoreSummary? {
        do {
            let summary = try await store.restore(tokens, mode: mode)
            await refresh()
            return summary
        } catch {
            errorMessage = error.localizedDescription
            return nil
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

    /// Stable identity of a token for duplicate detection: secret plus the
    /// normalized issuer/account.
    nonisolated static func fingerprint(_ token: OTPToken) -> String {
        let issuer = token.issuer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let account = token.accountName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "\(token.secret.base64EncodedString())|\(issuer)|\(account)"
    }

    /// One pass over the stored tokens, for import screens that would otherwise
    /// run an O(n²) comparison on the main actor.
    func duplicateFingerprints() -> Set<String> {
        Set(tokens.map(Self.fingerprint))
    }

    func isDuplicate(_ token: OTPToken) -> Bool {
        let fingerprint = Self.fingerprint(token)
        return tokens.contains { Self.fingerprint($0) == fingerprint }
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
        let expiresIn = Self.clipboardExpiryEnabled ? 30.0 : nil
        Clipboard.copy(code, expiresIn: expiresIn)
        copySignal += 1
        showToast(expiresIn == nil ? L10n.t("已复制") : L10n.t("已复制 · 30 秒后清除"))
    }

    private static var clipboardExpiryEnabled: Bool {
        (UserDefaults.standard.object(forKey: "clipboardExpiryEnabled") as? Bool) ?? true
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
        Clipboard.copy(code, expiresIn: Self.clipboardExpiryEnabled ? 30.0 : nil)
        copySignal += 1
        showToast(L10n.format("已生成并复制 %@", OTPCodeFormatter.grouped(code)))

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
            OTPToken(issuer: L10n.t("内网服务"), accountName: "ops@intra", secret: Base32.decode("MZXW6YTBOI") ?? Data()),
            OTPToken(issuer: L10n.t("企业单点登录"), accountName: "long.name@example.com", secret: Base32.decode("GEZDGNBVGY3TQOJQ") ?? Data()),
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