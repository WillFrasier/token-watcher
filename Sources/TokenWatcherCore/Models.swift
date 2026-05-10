import Foundation

public struct TokenUsage: Equatable, Sendable {
    public var inputTokens: Int
    public var outputTokens: Int
    public var cacheCreationTokens: Int
    public var cacheReadTokens: Int
    public var costUSD: Double

    public init(
        inputTokens: Int = 0,
        outputTokens: Int = 0,
        cacheCreationTokens: Int = 0,
        cacheReadTokens: Int = 0,
        costUSD: Double = 0
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheCreationTokens = cacheCreationTokens
        self.cacheReadTokens = cacheReadTokens
        self.costUSD = costUSD
    }

    public var totalTokens: Int {
        inputTokens + outputTokens + cacheCreationTokens + cacheReadTokens
    }

    public static func += (lhs: inout TokenUsage, rhs: TokenUsage) {
        lhs.inputTokens += rhs.inputTokens
        lhs.outputTokens += rhs.outputTokens
        lhs.cacheCreationTokens += rhs.cacheCreationTokens
        lhs.cacheReadTokens += rhs.cacheReadTokens
        lhs.costUSD += rhs.costUSD
    }

    public static func + (lhs: TokenUsage, rhs: TokenUsage) -> TokenUsage {
        var r = lhs; r += rhs; return r
    }
}

public struct UsageEntry: Sendable {
    public let timestamp: Date
    public let model: String
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheCreationTokens: Int
    public let cacheReadTokens: Int
    public let sessionId: String
    public let isSidechain: Bool
    public let cwd: String?
    public let gitBranch: String?
    public let speed: String

    public init(
        timestamp: Date,
        model: String,
        inputTokens: Int,
        outputTokens: Int,
        cacheCreationTokens: Int,
        cacheReadTokens: Int,
        sessionId: String,
        isSidechain: Bool,
        cwd: String?,
        gitBranch: String?,
        speed: String
    ) {
        self.timestamp = timestamp
        self.model = model
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheCreationTokens = cacheCreationTokens
        self.cacheReadTokens = cacheReadTokens
        self.sessionId = sessionId
        self.isSidechain = isSidechain
        self.cwd = cwd
        self.gitBranch = gitBranch
        self.speed = speed
    }
}

public struct ProjectUsage: Identifiable, Sendable {
    public let id: String
    public let displayName: String
    public let fullPath: String
    public var todayUsage: TokenUsage
    public var weekUsage: TokenUsage
    public var monthUsage: TokenUsage
    public var recentUsage: TokenUsage
    public var totalSessions: Int
    public var recentSessions: Int
    public var subAgentCount: Int
    public var lastActivity: Date?
    public var isAlerting: Bool
    public var alertReason: String?
    public var colorIndex: Int
    public var seriesToday: [Int]
    public var seriesWeek: [Int]
    public var seriesMonth: [Int]
    public var costSeriesToday: [Double]
    public var costSeriesWeek: [Double]
    public var costSeriesMonth: [Double]

    public init(
        id: String,
        displayName: String,
        fullPath: String,
        todayUsage: TokenUsage,
        weekUsage: TokenUsage,
        monthUsage: TokenUsage,
        recentUsage: TokenUsage,
        totalSessions: Int,
        recentSessions: Int,
        subAgentCount: Int,
        lastActivity: Date?,
        isAlerting: Bool,
        alertReason: String?,
        colorIndex: Int,
        seriesToday: [Int],
        seriesWeek: [Int],
        seriesMonth: [Int],
        costSeriesToday: [Double],
        costSeriesWeek: [Double],
        costSeriesMonth: [Double]
    ) {
        self.id = id
        self.displayName = displayName
        self.fullPath = fullPath
        self.todayUsage = todayUsage
        self.weekUsage = weekUsage
        self.monthUsage = monthUsage
        self.recentUsage = recentUsage
        self.totalSessions = totalSessions
        self.recentSessions = recentSessions
        self.subAgentCount = subAgentCount
        self.lastActivity = lastActivity
        self.isAlerting = isAlerting
        self.alertReason = alertReason
        self.colorIndex = colorIndex
        self.seriesToday = seriesToday
        self.seriesWeek = seriesWeek
        self.seriesMonth = seriesMonth
        self.costSeriesToday = costSeriesToday
        self.costSeriesWeek = costSeriesWeek
        self.costSeriesMonth = costSeriesMonth
    }
}

public enum TimeWindow: String, CaseIterable, Identifiable {
    case today = "Today"
    case week = "7 Days"
    case month = "30 Days"
    public var id: String { rawValue }
}
