import Foundation
import Testing
@testable import OTP

struct TOTPTests {
    private let sha1Secret = Data("12345678901234567890".utf8)
    private let sha256Secret = Data("12345678901234567890123456789012".utf8)
    private let sha512Secret = Data("1234567890123456789012345678901234567890123456789012345678901234".utf8)

    private func date(_ seconds: TimeInterval) -> Date {
        Date(timeIntervalSince1970: seconds)
    }

    @Test func matchesRFC6238SHA1Vectors() {
        let vectors: [(TimeInterval, String)] = [
            (59, "94287082"),
            (1_111_111_109, "07081804"),
            (1_111_111_111, "14050471"),
            (1_234_567_890, "89005924"),
            (2_000_000_000, "69279037"),
            (20_000_000_000, "65353130"),
        ]
        for (seconds, expected) in vectors {
            let code = TOTP.code(secret: sha1Secret, at: date(seconds), period: 30, digits: 8, algorithm: .sha1)
            #expect(code == expected, "t=\(seconds)")
        }
    }

    @Test func matchesRFC6238SHA256Vectors() {
        let vectors: [(TimeInterval, String)] = [
            (59, "46119246"),
            (1_111_111_109, "68084774"),
            (1_111_111_111, "67062674"),
            (1_234_567_890, "91819424"),
            (2_000_000_000, "90698825"),
            (20_000_000_000, "77737706"),
        ]
        for (seconds, expected) in vectors {
            let code = TOTP.code(secret: sha256Secret, at: date(seconds), period: 30, digits: 8, algorithm: .sha256)
            #expect(code == expected, "t=\(seconds)")
        }
    }

    @Test func matchesRFC6238SHA512Vectors() {
        let vectors: [(TimeInterval, String)] = [
            (59, "90693936"),
            (1_111_111_109, "25091201"),
            (1_111_111_111, "99943326"),
            (1_234_567_890, "93441116"),
            (2_000_000_000, "38618901"),
            (20_000_000_000, "47863826"),
        ]
        for (seconds, expected) in vectors {
            let code = TOTP.code(secret: sha512Secret, at: date(seconds), period: 30, digits: 8, algorithm: .sha512)
            #expect(code == expected, "t=\(seconds)")
        }
    }

    @Test func computesCountersAndRemaining() {
        #expect(TOTP.counter(at: date(0), period: 30) == 0)
        #expect(TOTP.counter(at: date(59.9), period: 30) == 1)
        #expect(TOTP.counter(at: date(60), period: 30) == 2)
        #expect(TOTP.remaining(at: date(60), period: 30) == 30)
        #expect(TOTP.remaining(at: date(89.5), period: 30) == 1)
        #expect(TOTP.remaining(at: date(75), period: 30) == 15)
        #expect(TOTP.progress(at: date(75), period: 30) == 0.5)
        #expect(TOTP.remaining(at: date(0), period: 1) == 1)
    }

    @Test func groupsCodes() {
        #expect(OTPCodeFormatter.grouped("123456") == "123 456")
        #expect(OTPCodeFormatter.grouped("1234567") == "1234 567")
        #expect(OTPCodeFormatter.grouped("12345678") == "1234 5678")
        #expect(OTPCodeFormatter.grouped("12345") == "12345")
    }
}
