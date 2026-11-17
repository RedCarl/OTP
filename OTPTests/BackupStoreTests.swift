import Foundation
import Testing
@testable import OTP

struct BackupStoreTests {
    private func tempDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    @Test func savesListsReadsAndDeletes() async throws {
        let directory = tempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = BackupStore(directory: directory)
        let payload = Data("encrypted-backup".utf8)
        let item = try await store.save(payload, date: Date(timeIntervalSince1970: 1_700_000_000))
        #expect(item.byteCount == payload.count)

        let items = try await store.list()
        #expect(items.count == 1)
        #expect(items.first?.id == item.id)
        #expect(try await store.read(item) == payload)

        try await store.delete(item)
        #expect(try await store.list().isEmpty)
    }

    @Test func keepsOnlyTenNewestBackups() async throws {
        let directory = tempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = BackupStore(directory: directory)
        for index in 0..<12 {
            let data = Data("backup-\(index)".utf8)
            _ = try await store.save(data, date: Date(timeIntervalSince1970: 1_700_000_000 + Double(index)))
        }

        let items = try await store.list()
        #expect(items.count == BackupStore.maxBackups)
        #expect(items.first?.createdAt ?? .distantPast > items.last?.createdAt ?? .distantFuture)
    }
}
