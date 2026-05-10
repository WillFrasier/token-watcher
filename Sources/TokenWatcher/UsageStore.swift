import Foundation
import Combine

@MainActor
final class UsageStore: ObservableObject {
    static let shared = UsageStore()

    @Published var projects: [ProjectUsage] = []
    @Published var totalUsage: TokenUsage = TokenUsage()
    @Published var lastUpdated: Date?
    @Published var isLoading = false
    @Published var loadError: String?

    private(set) var rawEntries: [String: [UsageEntry]] = [:]
    private var timer: Timer?
    private let settings = AppSettings.shared

    private init() {
        setupTimer()
        Task { await refresh() }

        NotificationCenter.default.addObserver(
            forName: .settingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.setupTimer() }
        }
    }

    func setupTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(
            withTimeInterval: TimeInterval(settings.updateIntervalSeconds),
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refresh()
            }
        }
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        loadError = nil

        do {
            let allEntries = try await Task.detached(priority: .utility) {
                try await UsageParser.parseAll()
            }.value

            rawEntries = allEntries
            let computed = buildProjectUsages(from: allEntries)
            projects = computed.sorted { $0.todayUsage.totalTokens > $1.todayUsage.totalTokens }
            totalUsage = projects.reduce(TokenUsage()) { $0 + $1.todayUsage }
            lastUpdated = Date()

            AlertsManager.shared.checkAlerts(projects: projects)
        } catch {
            loadError = error.localizedDescription
        }

        isLoading = false
    }

    private func buildProjectUsages(from allEntries: [String: [UsageEntry]]) -> [ProjectUsage] {
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let oneHourAgo = now.addingTimeInterval(-3_600)
        let sevenDaysAgo = now.addingTimeInterval(-7 * 86_400)
        let thirtyDaysAgo = now.addingTimeInterval(-30 * 86_400)

        return allEntries.compactMap { (projectId, entries) -> ProjectUsage? in
            let cwd = entries.compactMap(\.cwd).first
            let displayName = projectDisplayName(projectId: projectId, cwd: cwd)
            let fullPath = cwd ?? decodePath(projectId)

            var todayUsage = TokenUsage()
            var weekUsage = TokenUsage()
            var monthUsage = TokenUsage()
            var recentUsage = TokenUsage()
            var allSessions = Set<String>()
            var recentSessions = Set<String>()
            var subAgentCount = 0
            var lastActivity: Date?

            for entry in entries {
                let cost = pricing(for: entry.model).cost(
                    input: entry.inputTokens,
                    output: entry.outputTokens,
                    cacheCreate: entry.cacheCreationTokens,
                    cacheRead: entry.cacheReadTokens
                )
                let eu = TokenUsage(
                    inputTokens: entry.inputTokens,
                    outputTokens: entry.outputTokens,
                    cacheCreationTokens: entry.cacheCreationTokens,
                    cacheReadTokens: entry.cacheReadTokens,
                    costUSD: cost
                )

                allSessions.insert(entry.sessionId)

                if entry.timestamp >= startOfDay {
                    todayUsage += eu
                    if entry.isSidechain { subAgentCount += 1 }
                }
                if entry.timestamp >= sevenDaysAgo { weekUsage += eu }
                if entry.timestamp >= thirtyDaysAgo { monthUsage += eu }
                if entry.timestamp >= oneHourAgo {
                    recentUsage += eu
                    recentSessions.insert(entry.sessionId)
                }
                if lastActivity == nil || entry.timestamp > lastActivity! {
                    lastActivity = entry.timestamp
                }
            }

            if settings.hideInactiveProjects && todayUsage.totalTokens == 0 { return nil }

            let costAlert = recentUsage.costUSD > settings.costAlertThreshold
            let agentAlert = recentSessions.count > settings.subAgentAlertThreshold
            let isAlerting = costAlert || agentAlert
            var alertReason: String?
            if costAlert { alertReason = "\(recentUsage.costUSD.formattedCost) spent in last hour" }
            else if agentAlert { alertReason = "\(recentSessions.count) sessions in last hour" }

            return ProjectUsage(
                id: projectId,
                displayName: displayName,
                fullPath: fullPath,
                todayUsage: todayUsage,
                weekUsage: weekUsage,
                monthUsage: monthUsage,
                recentUsage: recentUsage,
                totalSessions: allSessions.count,
                recentSessions: recentSessions.count,
                subAgentCount: subAgentCount,
                lastActivity: lastActivity,
                isAlerting: isAlerting,
                alertReason: alertReason,
                colorIndex: projectColorIndex(for: projectId),
                seriesToday: computeSeries(entries: entries, bucketCount: 24, bucketDuration: 3_600),
                seriesWeek: computeSeries(entries: entries, bucketCount: 168, bucketDuration: 3_600),
                seriesMonth: computeSeries(entries: entries, bucketCount: 30, bucketDuration: 86_400),
                costSeriesToday: computeCostSeries(entries: entries, bucketCount: 24, bucketDuration: 3_600),
                costSeriesWeek: computeCostSeries(entries: entries, bucketCount: 168, bucketDuration: 3_600),
                costSeriesMonth: computeCostSeries(entries: entries, bucketCount: 30, bucketDuration: 86_400)
            )
        }
    }

    func entries(for projectId: String) -> [UsageEntry] {
        rawEntries[projectId] ?? []
    }

    func usageForWindow(_ window: TimeWindow, project: ProjectUsage) -> TokenUsage {
        switch window {
        case .today: return project.todayUsage
        case .week: return project.weekUsage
        case .month: return project.monthUsage
        }
    }

    func totalForWindow(_ window: TimeWindow) -> TokenUsage {
        projects.reduce(TokenUsage()) { $0 + usageForWindow(window, project: $1) }
    }

    private func projectDisplayName(projectId: String, cwd: String?) -> String {
        if let cwd, !cwd.isEmpty {
            let components = cwd.split(separator: "/").filter { !$0.isEmpty }
            if components.count >= 2 {
                return String(components.suffix(2).joined(separator: "/"))
            }
            return components.last.map(String.init) ?? cwd
        }
        return decodePath(projectId)
            .split(separator: "/").filter { !$0.isEmpty }
            .suffix(2).joined(separator: "/")
    }

    private func decodePath(_ encoded: String) -> String {
        guard encoded.hasPrefix("-") else { return encoded }
        return "/" + String(encoded.dropFirst()).replacingOccurrences(of: "-", with: "/")
    }

    private func computeCostSeries(entries: [UsageEntry], bucketCount: Int, bucketDuration: TimeInterval) -> [Double] {
        let now = Date()
        var buckets = [Double](repeating: 0, count: bucketCount)
        for entry in entries {
            let elapsed = now.timeIntervalSince(entry.timestamp)
            guard elapsed >= 0 else { continue }
            let bucket = Int(elapsed / bucketDuration)
            guard bucket < bucketCount else { continue }
            buckets[bucketCount - 1 - bucket] += pricing(for: entry.model).cost(
                input: entry.inputTokens, output: entry.outputTokens,
                cacheCreate: entry.cacheCreationTokens, cacheRead: entry.cacheReadTokens
            )
        }
        return buckets
    }

    private func computeSeries(entries: [UsageEntry], bucketCount: Int, bucketDuration: TimeInterval) -> [Int] {
        let now = Date()
        var buckets = [Int](repeating: 0, count: bucketCount)
        for entry in entries {
            let elapsed = now.timeIntervalSince(entry.timestamp)
            guard elapsed >= 0 else { continue }
            let bucket = Int(elapsed / bucketDuration)
            guard bucket < bucketCount else { continue }
            buckets[bucketCount - 1 - bucket] += entry.inputTokens + entry.outputTokens
                + entry.cacheCreationTokens + entry.cacheReadTokens
        }
        return buckets
    }
}

extension Notification.Name {
    static let settingsDidChange = Notification.Name("TokenWatcher.settingsDidChange")
}
