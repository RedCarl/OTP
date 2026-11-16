import Foundation
import Testing
@testable import OTP

struct FileImportTests {
    private let aegisJSON = """
    {"version":1,"header":{},"db":{"version":1,"entries":[
      {"type":"totp","uuid":"u1","name":"alice","issuer":"GitHub","favorite":true,
       "info":{"secret":"JBSWY3DPEHPK3PXP","algo":"SHA1","digits":6,"period":30}},
      {"type":"hotp","uuid":"u2","name":"admin","issuer":"AWS",
       "info":{"secret":"MFRGGZDFMZTWQ2LKNNWG23TP","algo":"SHA512","digits":8,"counter":9}}
    ]}}
    """

    private let aegisEncryptedJSON = """
    {"version":1,"header":{"slots":[{"type":1,"uuid":"x","key":"y","n":32768,"r":8,"p":1,"salt":"z","algo":"AES256"}]},"db":{}}
    """

    private let twoFASJSON = """
    {"schemaVersion":4,"services":[
      {"name":"GitHub","secret":"JBSWY3DPEHPK3PXP",
       "otp":{"label":"GitHub","account":"alice","issuer":"GitHub","digits":6,"period":30,"algorithm":"SHA1","tokenType":"TOTP"}},
      {"name":"AWS","secret":"MFRGGZDFMZTWQ2LKNNWG23TP",
       "otp":{"account":"admin","issuer":"AWS","digits":6,"period":30,"algorithm":"SHA1","tokenType":"HOTP","counter":3}}
    ]}
    """

    @Test func importsAegisPlaintext() throws {
        let outcome = try AegisImport.parse(Data(aegisJSON.utf8))
        #expect(outcome.format == .aegis)
        #expect(outcome.candidates.count == 2)
        let first = try #require(outcome.candidates.first?.token)
        #expect(first.issuer == "GitHub")
        #expect(first.accountName == "alice")
        #expect(first.pinned == true)
        let second = try #require(outcome.candidates.last?.token)
        #expect(second.kind == .hotp)
        #expect(second.algorithm == .sha512)
        #expect(second.counter == 9)
    }

    @Test func rejectsEncryptedAegis() {
        #expect(throws: ImportError.encryptedAegis) {
            try AegisImport.parse(Data(aegisEncryptedJSON.utf8))
        }
    }

    @Test func importsTwoFASPlaintext() throws {
        let outcome = try TwoFASImport.parse(Data(twoFASJSON.utf8))
        #expect(outcome.format == .twoFAS)
        #expect(outcome.candidates.count == 2)
        let second = try #require(outcome.candidates.last?.token)
        #expect(second.kind == .hotp)
        #expect(second.counter == 3)
    }

    @Test func rejectsEncryptedTwoFAS() {
        let json = """
        {"schemaVersion":4,"services":[],"servicesEncrypted":"ZW5jcnlwdGVk"}
        """
        #expect(throws: ImportError.encryptedTwoFAS) {
            try TwoFASImport.parse(Data(json.utf8))
        }
    }

    @Test func importServiceRoutesFiles() throws {
        let service = ImportService()
        #expect(try service.parseFile(Data(aegisJSON.utf8), passphrase: nil).format == .aegis)
        #expect(try service.parseFile(Data(twoFASJSON.utf8), passphrase: nil).format == .twoFAS)

        let backup = BackupService()
        let tokens = [OTPToken(issuer: "GitHub", accountName: "alice", secret: Base32.decode("JBSWY3DPEHPK3PXP") ?? Data())]
        let backupData = try backup.export(tokens, passphrase: nil)
        let outcome = try service.parseFile(backupData, passphrase: nil)
        #expect(outcome.format == .backup)
        #expect(outcome.validTokens.count == 1)

        #expect(throws: ImportError.unsupportedFile) {
            try service.parseFile(Data("not a backup".utf8), passphrase: nil)
        }
    }

    @Test func importServiceHandlesEncryptedBackupPassphrase() throws {
        let backup = BackupService(iterations: 1_000)
        let tokens = [OTPToken(issuer: "GitHub", accountName: "alice", secret: Base32.decode("JBSWY3DPEHPK3PXP") ?? Data())]
        let data = try backup.export(tokens, passphrase: "correct horse battery")

        let service = ImportService(backupService: backup)
        #expect(throws: BackupError.missingPassphrase) {
            try service.parseFile(data, passphrase: nil)
        }
        let outcome = try service.parseFile(data, passphrase: "correct horse battery")
        #expect(outcome.validTokens.count == 1)
    }

    @Test func parsesMultipleURILines() throws {
        let text = """
        otpauth://totp/GitHub:alice?secret=JBSWY3DPEHPK3PXP
        otpauth://totp/Google:bob?secret=GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ&digits=8
        not a link
        """
        let outcome = try ImportService().parseText(text)
        #expect(outcome.candidates.count == 3)
        #expect(outcome.validTokens.count == 2)
        #expect(outcome.errorCount == 1)
        #expect(outcome.validTokens[1].digits == 8)
    }

    @Test func rejectsTextWithoutTokens() {
        #expect(throws: ImportError.noRecognizableTokens) {
            try ImportService().parseText("hello world")
        }
    }

    @Test func importServiceImportsMigrationURLText() throws {
        let secret = Base32.decode("JBSWY3DPEHPK3PXP") ?? Data()
        var message: [UInt8] = []
        func varint(_ value: UInt64) -> [UInt8] {
            var value = value
            var bytes: [UInt8] = []
            repeat {
                var byte = UInt8(value & 0x7F)
                value >>= 7
                if value != 0 { byte |= 0x80 }
                bytes.append(byte)
            } while value != 0
            return bytes
        }
        func tag(_ field: Int, _ wire: Int) -> [UInt8] { varint(UInt64(field << 3 | wire)) }
        func bytesField(_ field: Int, _ payload: [UInt8]) -> [UInt8] { tag(field, 2) + varint(UInt64(payload.count)) + payload }
        func varintField(_ field: Int, _ value: UInt64) -> [UInt8] { tag(field, 0) + varint(value) }

        message += bytesField(1, [UInt8](secret))
        message += bytesField(2, Array("alice".utf8))
        message += bytesField(3, Array("GitHub".utf8))
        message += varintField(4, 1)
        message += varintField(5, 1)
        message += varintField(6, 2)
        message += bytesField(1, message)
        let base64 = Data(message).base64EncodedString()

        let outcome = try ImportService().parseText("otpauth-migration://offline?data=" + base64)
        #expect(outcome.validTokens.count == 1)
        #expect(outcome.validTokens[0].issuer == "GitHub")
    }
}
