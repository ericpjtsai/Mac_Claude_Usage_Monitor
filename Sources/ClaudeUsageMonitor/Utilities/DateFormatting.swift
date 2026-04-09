import Foundation

enum DateFormatting {

    // MARK: - ISO8601 Parsing

    private static let iso8601WithFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let iso8601Standard: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func parseISO8601(_ string: String) -> Date? {
        iso8601WithFractional.date(from: string) ?? iso8601Standard.date(from: string)
    }

    // MARK: - Countdown

    /// Returns a human-readable countdown like "2h 34m" or "5m"
    static func countdown(to date: Date, from now: Date = Date()) -> String {
        let interval = date.timeIntervalSince(now)
        guard interval > 0 else { return "now" }

        let totalMinutes = Int(interval / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    // MARK: - Relative Time

    /// Returns a relative time like "2 min ago" or "just now"
    static func relativeTime(from date: Date, to now: Date = Date()) -> String {
        let interval = now.timeIntervalSince(date)
        guard interval > 0 else { return "just now" }

        let minutes = Int(interval / 60)
        if minutes < 1 { return "just now" }
        if minutes == 1 { return "1 min ago" }
        if minutes < 60 { return "\(minutes) min ago" }

        let hours = minutes / 60
        if hours == 1 { return "1 hour ago" }
        return "\(hours) hours ago"
    }
}
