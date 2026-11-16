import Foundation
import Testing
@testable import OTP

struct HOTPTests {
    private let secret = Data("12345678901234567890".utf8)
    private let rfc4226Codes = [
        "755224", "287082", "359152", "969429", "338314",
        "254676", "287922", "162583", "399871", "520489",
    ]

    @Test func matchesRFC4226Vectors() {
        for (counter, expected) in rfc4226Codes.enumerated() {
            let code = HOTP.code(secret: secret, counter: UInt64(counter), digits: 6)
            #expect(code == expected, "counter \(counter)")
        }
    }

    @Test func supportsEightDigits() {
        let code = HOTP.code(secret: secret, counter: 1, digits: 8)
        #expect(code.count == 8)
        #expect(code.hasSuffix("287082"))
    }

    @Test func rejectsUnsupportedDigitCount() {
        #expect(HOTP.code(secret: secret, counter: 0, digits: 5).isEmpty)
        #expect(HOTP.code(secret: secret, counter: 0, digits: 9).isEmpty)
    }
}
