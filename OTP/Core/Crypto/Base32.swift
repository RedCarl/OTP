import Foundation

/// RFC 4648 Base32 used by otpauth secrets. Tolerant on input (case, spaces,
/// dashes and trailing padding), strict about the residual bits on decode.
enum Base32 {
    static let alphabet: [Character] = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")
    private static let lookup: [Character: UInt8] = {
        var table: [Character: UInt8] = [:]
        for (index, character) in alphabet.enumerated() {
            table[character] = UInt8(index)
        }
        return table
    }()

    static func decode(_ string: String) -> Data? {
        var cleaned = string.uppercased()
        cleaned = String(cleaned.filter { character in
            !character.isWhitespace && character != "-" && character != "_"
        })
        while cleaned.hasSuffix("=") {
            cleaned.removeLast()
        }
        guard !cleaned.isEmpty else { return nil }

        var buffer: UInt32 = 0
        var bitCount = 0
        var bytes: [UInt8] = []
        bytes.reserveCapacity(cleaned.count * 5 / 8)

        for character in cleaned {
            guard let value = lookup[character] else { return nil }
            buffer = (buffer << 5) | UInt32(value)
            bitCount += 5
            while bitCount >= 8 {
                bitCount -= 8
                bytes.append(UInt8((buffer >> UInt32(bitCount)) & 0xFF))
            }
        }

        if bitCount > 0 {
            let mask: UInt32 = (1 << UInt32(bitCount)) - 1
            guard (buffer & mask) == 0 else { return nil }
        }
        return Data(bytes)
    }

    static func encode(_ data: Data) -> String {
        guard !data.isEmpty else { return "" }
        var result = ""
        result.reserveCapacity((data.count * 8 + 4) / 5)
        var buffer: UInt32 = 0
        var bitCount = 0
        for byte in data {
            buffer = (buffer << 8) | UInt32(byte)
            bitCount += 8
            while bitCount >= 5 {
                bitCount -= 5
                result.append(alphabet[Int((buffer >> UInt32(bitCount)) & 0x1F)])
            }
        }
        if bitCount > 0 {
            result.append(alphabet[Int((buffer << UInt32(5 - bitCount)) & 0x1F)])
        }
        return result
    }
}
