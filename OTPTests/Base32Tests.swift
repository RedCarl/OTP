import Foundation
import Testing
@testable import OTP

struct Base32Tests {
    @Test func decodesRFC4648Vectors() {
        #expect(Base32.decode("MY======") == Data("f".utf8))
        #expect(Base32.decode("MZXQ====") == Data("fo".utf8))
        #expect(Base32.decode("MZXW6===") == Data("foo".utf8))
        #expect(Base32.decode("MZXW6YQ=") == Data("foob".utf8))
        #expect(Base32.decode("MZXW6YTB") == Data("fooba".utf8))
        #expect(Base32.decode("MZXW6YTBOI======") == Data("foobar".utf8))
        #expect(Base32.decode("mzxw6ytboi======") == Data("foobar".utf8))
        #expect(Base32.decode("MZXW 6YTB") == Data("fooba".utf8))
        #expect(Base32.decode("MZXW-6YTB") == Data("fooba".utf8))
    }

    @Test func rejectsInvalidInput() {
        #expect(Base32.decode("") == nil)
        #expect(Base32.decode("MZXW6YT1") == nil)
        #expect(Base32.decode("MZXW6YT@") == nil)
        // Residual bits must be zero for a canonical encoding.
        #expect(Base32.decode("MZ") == nil)
    }

    @Test func roundTripsArbitraryBytes() {
        let samples: [Data] = [
            Data([0]),
            Data([0xFF]),
            Data([0x00, 0x01, 0x02, 0x03, 0x04]),
            Data((0..<64).map { UInt8($0 * 4 % 256) }),
        ]
        for sample in samples {
            let encoded = Base32.encode(sample)
            #expect(Base32.decode(encoded) == sample)
        }
    }

    @Test func encodesKnownSecret() {
        let secret = Data("Hello!".utf8) + Data([0xDE, 0xAD, 0xBE, 0xEF])
        #expect(Base32.encode(secret) == "JBSWY3DPEHPK3PXP")
        #expect(Base32.decode("JBSWY3DPEHPK3PXP") == secret)
    }
}
