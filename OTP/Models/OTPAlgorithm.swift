import Foundation
import CryptoKit

enum OTPAlgorithm: String, Codable, CaseIterable, Sendable {
    case sha1
    case sha256
    case sha512

    var displayName: String {
        switch self {
        case .sha1: "SHA-1"
        case .sha256: "SHA-256"
        case .sha512: "SHA-512"
        }
    }

    func hmac(key: Data, message: Data) -> Data {
        let symmetricKey = SymmetricKey(data: key)
        switch self {
        case .sha1:
            return Data(HMAC<Insecure.SHA1>.authenticationCode(for: message, using: symmetricKey))
        case .sha256:
            return Data(HMAC<SHA256>.authenticationCode(for: message, using: symmetricKey))
        case .sha512:
            return Data(HMAC<SHA512>.authenticationCode(for: message, using: symmetricKey))
        }
    }
}
