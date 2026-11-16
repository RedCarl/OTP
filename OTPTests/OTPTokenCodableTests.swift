import Foundation
import Testing
@testable import OTP

struct OTPTokenCodableTests {
    private func makeToken() -> OTPToken {
        OTPToken(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            issuer: "GitHub",
            accountName: "alice",
            secret: Data("Hello!".utf8) + Data([0xDE, 0xAD, 0xBE, 0xEF]),
            kind: .totp,
            algorithm: .sha512,
            digits: 7,
            period: 45,
            counter: 3,
            pinned: true,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_123)
        )
    }

    @Test func roundTripsThroughJSON() throws {
        let token = makeToken()
        let data = try JSONEncoder().encode(token)
        let decoded = try JSONDecoder().decode(OTPToken.self, from: data)
        #expect(decoded.id == token.id)
        #expect(decoded.issuer == token.issuer)
        #expect(decoded.accountName == token.accountName)
        #expect(decoded.secret == token.secret)
        #expect(decoded.kind == token.kind)
        #expect(decoded.algorithm == token.algorithm)
        #expect(decoded.digits == token.digits)
        #expect(decoded.period == token.period)
        #expect(decoded.counter == token.counter)
        #expect(decoded.pinned == token.pinned)
        #expect(abs(decoded.createdAt.timeIntervalSince(token.createdAt)) < 0.01)
        #expect(abs(decoded.updatedAt.timeIntervalSince(token.updatedAt)) < 0.01)
    }

    @Test func writesSchemaFields() throws {
        let data = try JSONEncoder().encode(makeToken())
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["v"] as? Int == 1)
        #expect(json["issuer"] as? String == "GitHub")
        #expect(json["account"] as? String == "alice")
        #expect(json["kind"] as? String == "totp")
        #expect(json["algo"] as? String == "sha512")
        #expect(json["secret"] as? String == "JBSWY3DPEHPK3PXP")
        #expect(json["pinned"] as? Bool == true)
        #expect(json["createdAt"] is String)
    }

    @Test func ignoresUnknownFields() throws {
        let json = """
        {"v":1,"id":"11111111-2222-3333-4444-555555555555","issuer":"X","account":"y",
         "kind":"totp","algo":"sha1","digits":6,"period":30,"counter":0,
         "secret":"JBSWY3DPEHPK3PXP","pinned":false,"createdAt":"2024-01-01T00:00:00.000Z",
         "updatedAt":"2024-01-01T00:00:00.000Z","future":"ignored"}
        """
        let token = try JSONDecoder().decode(OTPToken.self, from: Data(json.utf8))
        #expect(token.issuer == "X")
    }

    @Test func rejectsNewerVersion() {
        let json = """
        {"v":2,"id":"11111111-2222-3333-4444-555555555555","secret":"JBSWY3DPEHPK3PXP"}
        """
        #expect(throws: OTPError.unsupportedVersion(2)) {
            try JSONDecoder().decode(OTPToken.self, from: Data(json.utf8))
        }
    }

    @Test func rejectsInvalidSecret() {
        let json = """
        {"v":1,"id":"11111111-2222-3333-4444-555555555555","secret":"not-base32!"}
        """
        #expect(throws: OTPError.invalidSecret) {
            try JSONDecoder().decode(OTPToken.self, from: Data(json.utf8))
        }
    }
}
