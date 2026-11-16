import Foundation

enum HOTP {
    /// RFC 4226 one-time password.
    static func code(secret: Data, counter: UInt64, digits: Int, algorithm: OTPAlgorithm = .sha1) -> String {
        guard (6...8).contains(digits) else { return "" }
        var bigEndianCounter = counter.bigEndian
        let message = withUnsafeBytes(of: &bigEndianCounter) { Data($0) }
        let hash = algorithm.hmac(key: secret, message: message)
        guard hash.count >= 20 else { return "" }

        let offset = Int(hash[hash.count - 1] & 0x0F)
        guard offset + 4 <= hash.count else { return "" }
        let truncated = (UInt32(hash[offset] & 0x7F) << 24)
            | (UInt32(hash[offset + 1]) << 16)
            | (UInt32(hash[offset + 2]) << 8)
            | UInt32(hash[offset + 3])

        let modulus: UInt32
        switch digits {
        case 6: modulus = 1_000_000
        case 7: modulus = 10_000_000
        default: modulus = 100_000_000
        }
        let value = truncated % modulus
        let text = String(value)
        return String(repeating: "0", count: max(0, digits - text.count)) + text
    }
}
