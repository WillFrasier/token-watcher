import Foundation

struct TokenUsage: Equatable, Sendable {
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var cacheCreationTokens: Int = 0
    var cacheReadTokens: Int = 0
    var costUSD: Double = 0

    var totalTokens: Int {
        inputTokens + outputTokens + cacheCreationTokens + cacheReadTokens
    }

    static func += (lhs: inout TokenUsage, rhs: TokenUsage) {
        lhs.inputTokens += rhs.inputTokens
        lhs.outputTokens += rhs.outputTokens
        lhs.cacheCreationTokens += rhs.cacheCreationTokens
        lhs.cacheReadTokens += rhs.cacheReadTokens
        lhs.costUSD += rhs.costUSD
    }

    static func + (lhs: TokenUsage, rhs: TokenUsage) -> TokenUsage {
        var r = lhs; r += rhs; return r
    }
}

struct UsageEntry: Sendable {
    let timestamp: Date
    let model: String
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int
    let sessionId: String
    let isSidechain: Bool
    let cwd: String?
    let gitBranch: String?
}

struct ProjectUsage: Identifiable, Sendable {
    let id: String
    let displayName: String
    let fullPath: String
    var todayUsage: TokenUsage
    var weekUsage: TokenUsage
    var monthUsage: TokenUsage
    var recentUsage: TokenUsage
    var totalSessions: Int
    var recentSessions: Int
    var subAgentCount: Int
    var lastActivity: Date?
    var isAlerting: Bool
    var alertReason: String?
    var colorIndex: Int
    var seriesToday: [Int]       // 24 hourly buckets
    var seriesWeek: [Int]        // 168 hourly buckets
    var seriesMonth: [Int]       // 30 daily buckets
    var costSeriesToday: [Double]
    var costSeriesWeek: [Double]
    var costSeriesMonth: [Double]
}

enum TimeWindow: String, CaseIterable, Identifiable {
    case today = "Today"
    case week = "7 Days"
    case month = "30 Days"
    var id: String { rawValue }
}

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var costAlertThreshold: Double {
        didSet { UserDefaults.standard.set(costAlertThreshold, forKey: Keys.costAlert) }
    }
    @Published var subAgentAlertThreshold: Int {
        didSet { UserDefaults.standard.set(subAgentAlertThreshold, forKey: Keys.subAgentAlert) }
    }
    @Published var updateIntervalSeconds: Int {
        didSet { UserDefaults.standard.set(updateIntervalSeconds, forKey: Keys.updateInterval) }
    }
    @Published var timeWindow: TimeWindow {
        didSet { UserDefaults.standard.set(timeWindow.rawValue, forKey: Keys.timeWindow) }
    }
    @Published var hideInactiveProjects: Bool {
        didSet { UserDefaults.standard.set(hideInactiveProjects, forKey: Keys.hideInactive) }
    }

    private enum Keys {
        static let costAlert = "costAlertThreshold"
        static let subAgentAlert = "subAgentAlertThreshold"
        static let updateInterval = "updateIntervalSeconds"
        static let timeWindow = "timeWindow"
        static let hideInactive = "hideInactiveProjects"
    }

    private init() {
        let ud = UserDefaults.standard
        let rawCostAlert = ud.double(forKey: Keys.costAlert)
        costAlertThreshold = rawCostAlert >= 0.5 ? rawCostAlert : 5.0
        let rawSubAgent = ud.integer(forKey: Keys.subAgentAlert)
        subAgentAlertThreshold = rawSubAgent > 0 ? rawSubAgent : 5
        let rawInterval = ud.integer(forKey: Keys.updateInterval)
        updateIntervalSeconds = rawInterval > 0 ? rawInterval : 60
        let rawWindow = ud.string(forKey: Keys.timeWindow) ?? TimeWindow.today.rawValue
        timeWindow = TimeWindow(rawValue: rawWindow) ?? .today
        hideInactiveProjects = ud.bool(forKey: Keys.hideInactive)
    }

    func reset() {
        costAlertThreshold = 5.0
        subAgentAlertThreshold = 5
        updateIntervalSeconds = 60
        timeWindow = .today
        hideInactiveProjects = false
    }
}
