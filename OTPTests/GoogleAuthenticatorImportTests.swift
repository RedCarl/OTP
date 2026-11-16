import Foundation
import Testing
@testable import OTP

struct GoogleAuthenticatorImportTests {
    // MARK: - Protobuf builders

    private func varint(_ value: UInt64) -> [UInt8] {
        var value = value
        var bytes: [UInt8] = []
        repeat {
            var byte = UInt8(value & 0x7F)
            value >>= 7
            if value != 0 { byte |= 0x80 }
            bytes.append(byte)
        } while value != 0
        return bytes
    }

    private func tag(_ field: Int, wire: Int) -> [UInt8] {
        varint(UInt64(field << 3 | wire))
    }

    private func varintField(_ field: Int, _ value: UInt64) -> [UInt8] {
        tag(field, wire: 0) + varint(value)
    }

    private func bytesField(_ field: Int, _ bytes: [UInt8]) -> [UInt8] {
        tag(field, wire: 2) + varint(UInt64(bytes.count)) + bytes
    }

    private func stringField(_ field: Int, _ string: String) -> [UInt8] {
        bytesField(field, Array(string.utf8))
    }

    private func parameters(
        secret: Data,
        name: String,
        issuer: String,
        algorithm: UInt64,
        digits: UInt64,
        type: UInt64,
        counter: UInt64
    ) -> [UInt8] {
        var bytes: [UInt8] = []
        bytes += bytesField(1, [UInt8](secret))
        bytes += stringField(2, name)
        bytes += stringField(3, issuer)
        bytes += varintField(4, algorithm)
        bytes += varintField(5, digits)
        bytes += varintField(6, type)
        bytes += varintField(7, counter)
        return bytes
    }

    private func payload(_ messages: [[UInt8]]) -> Data {
        Data(messages.flatMap { bytesField(1, $0) })
    }

    // MARK: - Tests

    @Test func parsesTOTPAndHOTPParameters() throws {
        let totp = parameters(
            secret: Base32.decode("JBSWY3DPEHPK3PXP") ?? Data(),
            name: "alice",
            issuer: "GitHub",
            algorithm: 1,
            digits: 1,
            type: 2,
            counter: 0
        )
        let hotp = parameters(
            secret: Base32.decode("MFRGGZDFMZTWQ2LKNNWG23TP") ?? Data(),
            name: "admin",
            issuer: "AWS",
            algorithm: 2,
            digits: 2,
            type: 1,
            counter: 5
        )

        let candidates = try GoogleAuthenticatorImport.parse(payload: payload([totp, hotp]))
        #expect(candidates.count == 2)
        #expect(candidates.allSatisfy { $0.token != nil })

        let first = try #require(candidates[0].token)
        #expect(first.issuer == "GitHub")
        #expect(first.accountName == "alice")
        #expect(first.kind == .totp)
        #expect(first.algorithm == .sha1)
        #expect(first.digits == 6)

        let second = try #require(candidates[1].token)
        #expect(second.kind == .hotp)
        #expect(second.algorithm == .sha256)
        #expect(second.digits == 8)
        #expect(second.counter == 5)
    }

    @Test func parsesMigrationURL() throws {
        let params = parameters(
            secret: Base32.decode("JBSWY3DPEHPK3PXP") ?? Data(),
            name: "GitHub:alice",
            issuer: "",
            algorithm: 1,
            digits: 1,
            type: 2,
            counter: 0
        )
        let base64 = payload([params]).base64EncodedString()
        let candidates = try GoogleAuthenticatorImport.parse(
            urlString: "otpauth-migration://offline?data=" + base64
        )
        let token = try #require(candidates.first?.token)
        #expect(token.issuer == "GitHub")
        #expect(token.accountName == "alice")
    }

    @Test func rejectsTruncatedPayload() {
        // Field 1, length 5, but only one byte present.
        let data = Data([0x0A, 0x05, 0x01])
        #expect(throws: (any Error).self) {
            try GoogleAuthenticatorImport.parse(payload: data)
        }
    }

    @Test func ignoresUnknownFields() throws {
        let secret = Base32.decode("JBSWY3DPEHPK3PXP") ?? Data()
        var message = parameters(secret: secret, name: "alice", issuer: "GitHub", algorithm: 1, digits: 1, type: 2, counter: 0)
        message += varintField(15, 99)          // unknown varint
        message += bytesField(16, [1, 2, 3])    // unknown bytes
        let candidates = try GoogleAuthenticatorImport.parse(payload: payload([message]))
        #expect(candidates.count == 1)
        #expect(candidates[0].errorMessage == nil)
    }

    @Test func flagsMD5Entries() throws {
        let params = parameters(
            secret: Base32.decode("JBSWY3DPEHPK3PXP") ?? Data(),
            name: "legacy",
            issuer: "Old",
            algorithm: 4,
            digits: 1,
            type: 2,
            counter: 0
        )
        let candidates = try GoogleAuthenticatorImport.parse(payload: payload([params]))
        #expect(candidates.count == 1)
        #expect(candidates[0].token == nil)
        #expect(candidates[0].errorMessage?.contains("MD5") == true)
    }
}
