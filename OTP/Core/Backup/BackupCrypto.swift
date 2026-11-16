import Foundation
import CryptoKit
import CommonCrypto

enum BackupCrypto {
    static let defaultIterations = 210_000
    static let keyLength = 32

    /// PBKDF2-HMAC-SHA256 (RFC 2898) via CommonCrypto.
    static func deriveKey(passphrase: String, salt: Data, iterations: Int, keyLength: Int = keyLength) throws -> Data {
        guard iterations > 0 else { throw BackupError.cryptoFailed }
        var derived = Data(count: keyLength)
        let passwordBytes = Array(passphrase.utf8)

        let status: Int32 = derived.withUnsafeMutableBytes { derivedBuffer in
            salt.withUnsafeBytes { saltBuffer in
                passwordBytes.withUnsafeBytes { passwordBuffer in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBuffer.baseAddress?.assumingMemoryBound(to: Int8.self),
                        passwordBytes.count,
                        saltBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(iterations),
                        derivedBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        keyLength
                    )
                }
            }
        }
        guard status == kCCSuccess else { throw BackupError.cryptoFailed }
        return derived
    }

    static func seal(payload: Data, passphrase: String, iterations: Int) throws -> (salt: Data, nonce: Data, ciphertext: Data, tag: Data) {
        var salt = Data(count: 16)
        let randomStatus = salt.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, 16, buffer.baseAddress!)
        }
        guard randomStatus == errSecSuccess else { throw BackupError.cryptoFailed }

        let keyData = try deriveKey(passphrase: passphrase, salt: salt, iterations: iterations)
        let key = SymmetricKey(data: keyData)
        let sealed = try AES.GCM.seal(payload, using: key)
        return (salt, Data(sealed.nonce), sealed.ciphertext, sealed.tag)
    }

    static func open(
        ciphertext: Data,
        tag: Data,
        nonce: Data,
        salt: Data,
        iterations: Int,
        passphrase: String
    ) throws -> Data {
        let keyData = try deriveKey(passphrase: passphrase, salt: salt, iterations: iterations)
        let key = SymmetricKey(data: keyData)
        do {
            let sealedBox = try AES.GCM.SealedBox(nonce: AES.GCM.Nonce(data: nonce), ciphertext: ciphertext, tag: tag)
            return try AES.GCM.open(sealedBox, using: key)
        } catch {
            throw BackupError.wrongPassphraseOrCorrupted
        }
    }
}
