import Foundation

struct BackupItem: Identifiable, Equatable, Sendable {
    let id: String
    let url: URL
    let createdAt: Date
    let byteCount: Int
    let isICloud: Bool

    var fileName: String { id }
}

/// Stores encrypted backup files in the app's iCloud Drive container:
/// iCloud Drive / OTP / Backups. Falls back to Application Support when
/// iCloud is unavailable (for example in a simulator without an account).
actor BackupStore {
    static let containerIdentifier = "iCloud.com.carljoy.otp"
    static let folderName = "Backups"
    static let fileExtension = "otpbackup"
    static let maxBackups = 10

    private let overrideDirectory: URL?
    private var cachedDirectory: URL?
    private var usingICloud = false

    init(directory: URL? = nil) {
        self.overrideDirectory = directory
    }

    func isUsingICloud() -> Bool {
        usingICloud
    }

    func list() async throws -> [BackupItem] {
        let directory = try await resolvedDirectory()
        let urls = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        let items: [BackupItem] = urls.compactMap { url in
            guard url.pathExtension == Self.fileExtension else { return nil }
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey])
            guard values?.isRegularFile != false else { return nil }
            let createdAt = Self.date(fromFileName: url.lastPathComponent)
                ?? values?.contentModificationDate
                ?? Date.distantPast
            return BackupItem(
                id: url.lastPathComponent,
                url: url,
                createdAt: createdAt,
                byteCount: values?.fileSize ?? 0,
                isICloud: usingICloud
            )
        }

        return items.sorted { $0.createdAt > $1.createdAt }
    }

    @discardableResult
    func save(_ data: Data, date: Date = Date()) async throws -> BackupItem {
        let directory = try await resolvedDirectory()
        let baseName = "OTP-\(Self.fileStamp(from: date))"
        var url = directory.appendingPathComponent("\(baseName).\(Self.fileExtension)")

        if FileManager.default.fileExists(atPath: url.path) {
            url = directory.appendingPathComponent("\(baseName)-\(UUID().uuidString.prefix(4)).\(Self.fileExtension)")
        }

        try writeCoordinated(data, to: url)
        try? FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)

        let item = BackupItem(
            id: url.lastPathComponent,
            url: url,
            createdAt: date,
            byteCount: data.count,
            isICloud: usingICloud
        )

        try trim()
        return item
    }

    func read(_ item: BackupItem) async throws -> Data {
        await ensureDownloaded(item.url)
        return try readCoordinated(item.url)
    }

    func delete(_ item: BackupItem) async throws {
        var coordinationError: NSError?
        var deleteError: Error?
        NSFileCoordinator(filePresenter: nil).coordinate(
            writingItemAt: item.url,
            options: .forDeleting,
            error: &coordinationError
        ) { url in
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                deleteError = error
            }
        }
        if let coordinationError { throw coordinationError }
        if let deleteError { throw deleteError }
    }

    func trim() throws {
        guard let directory = cachedDirectory else { return }
        let urls = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        let backups = urls
            .filter { $0.pathExtension == Self.fileExtension }
            .sorted { lhs, rhs in
                let left = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let right = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return left > right
            }
        for old in backups.dropFirst(Self.maxBackups) {
            try? FileManager.default.removeItem(at: old)
        }
    }

    // MARK: - Directory

    private func resolvedDirectory() async throws -> URL {
        if let cachedDirectory {
            return cachedDirectory
        }

        let directory: URL
        if let overrideDirectory {
            directory = overrideDirectory
            usingICloud = false
        } else {
            let container = await Task.detached(priority: .utility) {
                FileManager.default.url(forUbiquityContainerIdentifier: Self.containerIdentifier)
            }.value

            if let container {
                directory = container
                    .appendingPathComponent("Documents", isDirectory: true)
                    .appendingPathComponent(Self.folderName, isDirectory: true)
                usingICloud = true
            } else {
                let support = try FileManager.default.url(
                    for: .applicationSupportDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: true
                )
                directory = support.appendingPathComponent(Self.folderName, isDirectory: true)
                usingICloud = false
            }
        }

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        cachedDirectory = directory
        return directory
    }

    private func ensureDownloaded(_ url: URL) async {
        guard usingICloud else { return }
        let values = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
        guard let status = values?.ubiquitousItemDownloadingStatus,
              status != .current,
              status != .downloaded else {
            return
        }

        try? FileManager.default.startDownloadingUbiquitousItem(at: url)
        for _ in 0..<20 {
            try? await Task.sleep(for: .milliseconds(200))
            let current = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
                .ubiquitousItemDownloadingStatus
            if current == .current || current == .downloaded {
                return
            }
        }
    }

    // MARK: - Coordinated file IO

    private final class Box<T>: @unchecked Sendable {
        var value: T?
        var error: Error?
    }

    private func writeCoordinated(_ data: Data, to url: URL) throws {
        let box = Box<Void>()
        var coordinationError: NSError?
        NSFileCoordinator(filePresenter: nil).coordinate(
            writingItemAt: url,
            options: [],
            error: &coordinationError
        ) { target in
            do {
                try data.write(to: target, options: .atomic)
            } catch {
                box.error = error
            }
        }
        if let coordinationError { throw coordinationError }
        if let error = box.error { throw error }
    }

    private func readCoordinated(_ url: URL) throws -> Data {
        let box = Box<Data>()
        var coordinationError: NSError?
        NSFileCoordinator(filePresenter: nil).coordinate(
            readingItemAt: url,
            options: [],
            error: &coordinationError
        ) { target in
            do {
                box.value = try Data(contentsOf: target)
            } catch {
                box.error = error
            }
        }
        if let coordinationError { throw coordinationError }
        if let error = box.error { throw error }
        guard let data = box.value else {
            throw CocoaError(.fileReadUnknown)
        }
        return data
    }

    // MARK: - Names

    private static func fileStamp(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.string(from: date)
    }

    private static func date(fromFileName name: String) -> Date? {
        guard name.hasPrefix("OTP-") else { return nil }
        let stamp = String(name.dropFirst(4).prefix(19))
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.date(from: stamp)
    }
}
