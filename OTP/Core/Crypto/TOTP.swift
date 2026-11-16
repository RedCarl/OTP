import Foundation

enum TOTP {
    /// Time step index for a given instant (RFC 6238).
    static func counter(at date: Date, period: Int) -> UInt64 {
        let safePeriod = max(1, period)
        let seconds = date.timeIntervalSince1970
        return UInt64(floor(seconds / Double(safePeriod)))
    }

    static func code(
        secret: Data,
        at date: Date,
        period: Int = 30,
        digits: Int = 6,
        algorithm: OTPAlgorithm = .sha1
    ) -> String {
        HOTP.code(secret: secret, counter: counter(at: date, period: period), digits: digits, algorithm: algorithm)
    }

    /// Seconds left until the current window rolls over, in 1...period.
    static func remaining(at date: Date, period: Int) -> Int {
        let safePeriod = max(1, period)
        let offset = date.timeIntervalSince1970.truncatingRemainder(dividingBy: Double(safePeriod))
        let remaining = Double(safePeriod) - offset
        return max(1, min(safePeriod, Int(ceil(remaining - 1e-6))))
    }

    /// 0...1 fraction of the current window that is still valid.
    static func progress(at date: Date, period: Int) -> Double {
        let safePeriod = max(1, period)
        return max(0, min(1, Double(remaining(at: date, period: safePeriod)) / Double(safePeriod)))
    }
}
