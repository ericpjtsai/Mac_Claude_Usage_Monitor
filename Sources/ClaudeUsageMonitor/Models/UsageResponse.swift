import Foundation

struct UsageResponse: Codable {
    let fiveHour: UsageBucket?
    let sevenDay: UsageBucket?
    let sevenDayOpus: UsageBucket?
    let sevenDaySonnet: UsageBucket?
    let sevenDayOauthApps: UsageBucket?
    let sevenDayCowork: UsageBucket?
    let extraUsage: ExtraUsage?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDayOpus = "seven_day_opus"
        case sevenDaySonnet = "seven_day_sonnet"
        case sevenDayOauthApps = "seven_day_oauth_apps"
        case sevenDayCowork = "seven_day_cowork"
        case extraUsage = "extra_usage"
    }

    /// The primary bucket to display
    var primaryBucket: UsageBucket? {
        fiveHour
    }

    /// All available buckets with display labels
    var allBuckets: [(label: String, bucket: UsageBucket)] {
        var result: [(String, UsageBucket)] = []
        if let b = fiveHour { result.append(("Session (5h)", b)) }
        if let b = sevenDay { result.append(("Weekly (7d)", b)) }
        if let b = sevenDayOpus { result.append(("Opus (7d)", b)) }
        if let b = sevenDaySonnet { result.append(("Sonnet (7d)", b)) }
        if let b = sevenDayOauthApps { result.append(("OAuth Apps (7d)", b)) }
        if let b = sevenDayCowork { result.append(("Cowork (7d)", b)) }
        return result
    }
}

struct UsageBucket: Codable {
    let utilization: Double
    let resetsAt: String?

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }

    var resetDate: Date? {
        guard let resetsAt else { return nil }
        return DateFormatting.parseISO8601(resetsAt)
    }
}

struct ExtraUsage: Codable {
    let isEnabled: Bool?
    let utilization: Double?
    let usedCredits: Int?
    let monthlyLimit: Int?

    enum CodingKeys: String, CodingKey {
        case isEnabled = "is_enabled"
        case utilization
        case usedCredits = "used_credits"
        case monthlyLimit = "monthly_limit"
    }

    var usedDollars: Double {
        Double(usedCredits ?? 0) / 100.0
    }

    var limitDollars: Double {
        Double(monthlyLimit ?? 0) / 100.0
    }
}

struct UserInfo: Codable {
    let email: String?
    let name: String?
    let plan: String?
}
