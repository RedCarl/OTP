import Foundation
import Testing
@testable import OTP

struct QRCodeRendererTests {
    @Test func rendersQRCodeImage() throws {
        let token = OTPToken(
            issuer: "GitHub",
            accountName: "alice",
            secret: Base32.decode("JBSWY3DPEHPK3PXP") ?? Data()
        )
        let image = try #require(QRCodeRenderer.image(for: token.uri))
        #expect(image.size.width > 100)
        #expect(image.size.width == image.size.height)
    }

    @Test func uriSurvivesQRRoundTrip() throws {
        let token = OTPToken(
            issuer: "ACME 公司",
            accountName: "bob@example.com",
            secret: Base32.decode("JBSWY3DPEHPK3PXP") ?? Data()
        )
        let uri = token.uri
        let reparsed = try OTPAuthURI.parse(uri)
        #expect(reparsed.issuer == token.issuer)
        #expect(reparsed.accountName == token.accountName)
        #expect(reparsed.secret == token.secret)
    }
}
