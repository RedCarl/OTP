import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let otpBackup = UTType(exportedAs: "cn.carljoy.otp.backup", conformingTo: .json)
}

struct OTPBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.otpBackup, .json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let contents = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        data = contents
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
