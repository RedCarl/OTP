import Foundation

enum OTPCodeFormatter {
    /// Groups a numeric code for display, e.g. "123 456" or "1234 5678".
    static func grouped(_ code: String) -> String {
        let characters = Array(code)
        guard characters.count >= 6 else { return code }
        let splitIndex: Int
        switch characters.count {
        case 6: splitIndex = 3
        case 7: splitIndex = 4
        default: splitIndex = 4
        }
        guard splitIndex < characters.count else { return code }
        let head = String(characters[..<splitIndex])
        let tail = String(characters[splitIndex...])
        return "\(head) \(tail)"
    }
}
