import Foundation
import Testing
@testable import OTP

struct OTPAuthURITests {
    @Test func parsesStandardTOTP() throws {
        let token = try OTPAuthURI.parse(
            "otpauth://totp/ACME%20Co:john.doe@email.com?secret=JBSWY3DPEHPK3PXP&issuer=ACME%20Co&algorithm=SHA1&digits=6&period=30"
        )
        #expect(token.issuer == "ACME Co")
        #expect(token.accountName == "john.doe@email.com")
        #expect(token.kind == .totp)
        #expect(token.algorithm == .sha1)
        #expect(token.digits == 6)
        #expect(token.period == 30)
        #expect(token.secret == Data("Hello!".utf8) + Data([0xDE, 0xAD, 0xBE, 0xEF]))
    }

    @Test func parsesLabelIssuerWithoutParameter() throws {
        let token = try OTPAuthURI.parse("otpauth://totp/GitHub:alice?secret=JBSWY3DPEHPK3PXP")
        #expect(token.issuer == "GitHub")
        #expect(token.accountName == "alice")
    }

    @Test func parsesAccountOnlyLabel() throws {
        let token = try OTPAuthURI.parse("otpauth://totp/alice%40example.com?secret=JBSWY3DPEHPK3PXP")
        #expect(token.issuer.isEmpty)
        #expect(token.accountName == "alice@example.com")
    }

    @Test func parsesHOTPWithCounter() throws {
        let token = try OTPAuthURI.parse("otpauth://hotp/ACME:alice?secret=JBSWY3DPEHPK3PXP&counter=42&digits=8")
        #expect(token.kind == .hotp)
        #expect(token.counter == 42)
        #expect(token.digits == 8)
    }

    @Test func rejectsMalformedValues() {
        #expect(throws: OTPError.notOTPAuthURL) {
            try OTPAuthURI.parse("https://example.com/totp?secret=JBSWY3DPEHPK3PXP")
        }
        #expect(throws: OTPError.unsupportedKind("steam")) {
            try OTPAuthURI.parse("otpauth://steam/alice?secret=JBSWY3DPEHPK3PXP")
        }
        #expect(throws: OTPError.missingSecret) {
            try OTPAuthURI.parse("otpauth://totp/GitHub:alice")
        }
        #expect(throws: OTPError.invalidSecret) {
            try OTPAuthURI.parse("otpauth://totp/GitHub:alice?secret=not-base32!")
        }
        #expect(throws: OTPError.invalidDigits(5)) {
            try OTPAuthURI.parse("otpauth://totp/GitHub:alice?secret=JBSWY3DPEHPK3PXP&digits=5")
        }
        #expect(throws: OTPError.invalidAlgorithm("MD5")) {
            try OTPAuthURI.parse("otpauth://totp/GitHub:alice?secret=JBSWY3DPEHPK3PXP&algorithm=MD5")
        }
    }

    @Test func serializesAndRoundTrips() throws {
        let original = OTPToken(
            issuer: "谷歌 账户",
            accountName: "someone@example.com",
            secret: Data("Hello!".utf8) + Data([0xDE, 0xAD, 0xBE, 0xEF]),
            kind: .totp,
            algorithm: .sha256,
            digits: 8,
            period: 60
        )
        let uri = OTPAuthURI.string(from: original)
        #expect(uri.hasPrefix("otpauth://totp/"))
        #expect(uri.contains("secret=JBSWY3DPEHPK3PXP"))

        let reparsed = try OTPAuthURI.parse(uri)
        #expect(reparsed.issuer == original.issuer)
        #expect(reparsed.accountName == original.accountName)
        #expect(reparsed.algorithm == .sha256)
        #expect(reparsed.digits == 8)
        #expect(reparsed.period == 60)
        #expect(reparsed.secret == original.secret)
    }
}
