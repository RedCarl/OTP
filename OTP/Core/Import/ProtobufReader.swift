import Foundation

/// Minimal protobuf wire-format reader: enough for
/// otpauth-migration payloads emitted by Google Authenticator.
struct ProtobufReader {
    private let bytes: [UInt8]
    private var index = 0

    init(_ data: Data) {
        bytes = [UInt8](data)
    }

    var isAtEnd: Bool { index >= bytes.count }

    mutating func readVarint() throws -> UInt64 {
        var result: UInt64 = 0
        var shift: UInt64 = 0
        while true {
            guard index < bytes.count else {
                throw ImportError.malformed(L10n.t("迁移数据被截断"))
            }
            let byte = bytes[index]
            index += 1
            result |= UInt64(byte & 0x7F) << shift
            if byte & 0x80 == 0 { return result }
            shift += 7
            guard shift <= 63 else {
                throw ImportError.malformed(L10n.t("迁移数据包含过长的 varint"))
            }
        }
    }

    mutating func readTag() throws -> (field: Int, wireType: Int) {
        let tag = try readVarint()
        let field = Int(tag >> 3)
        let wireType = Int(tag & 0x07)
        guard field > 0 else {
            throw ImportError.malformed(L10n.t("迁移数据包含非法字段编号"))
        }
        return (field, wireType)
    }

    mutating func readBytes() throws -> Data {
        let length = try readVarint()
        guard length <= UInt64(bytes.count - index) else {
            throw ImportError.malformed(L10n.t("迁移数据长度越界"))
        }
        let start = index
        index += Int(length)
        return Data(bytes[start..<index])
    }

    mutating func readString() throws -> String {
        let data = try readBytes()
        return String(data: data, encoding: .utf8) ?? ""
    }

    mutating func skip(wireType: Int) throws {
        switch wireType {
        case 0:
            _ = try readVarint()
        case 1:
            try advance(8)
        case 2:
            _ = try readBytes()
        case 5:
            try advance(4)
        default:
            throw ImportError.malformed(L10n.t("迁移数据包含不支持的字段类型"))
        }
    }

    private mutating func advance(_ count: Int) throws {
        guard count <= bytes.count - index else {
            throw ImportError.malformed(L10n.t("迁移数据被截断"))
        }
        index += count
    }
}
