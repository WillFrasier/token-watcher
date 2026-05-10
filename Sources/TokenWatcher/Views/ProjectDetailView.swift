import SwiftUI
import TokenWatcherCore

@MainActor
struct ProjectDetailView: View {
    let project: ProjectUsage
    let timeWindow: TimeWindow
    let onBack: () -> Void

    @State private var stats: DetailStats? = nil

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            if let stats {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        summarySection(stats)
                        metaSection(stats)
                        tokenMixSection(stats)
                        if !stats.models.isEmpty { modelsSection(stats) }
                        if !stats.branches.isEmpty { branchesSection(stats) }
                        activitySection
                    }
                    .padding(14)
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 200)
            }
        }
        .frame(width: 340, height: 580)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: panelCornerRadius))
        .task { computeStats() }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 0) {
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Back")
                        .font(.system(size: 13))
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .pointerCursor()
            Spacer()
            Text(project.displayName)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 180)
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "chevron.left").font(.system(size: 12))
                Text("Back").font(.system(size: 13))
            }
            .opacity(0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Summary

    private func summarySection(_ stats: DetailStats) -> some View {
        HStack(spacing: 0) {
            summaryCell(label: "Cost", value: stats.usage.costUSD.formattedCost, color: .green)
            Divider().frame(height: 32)
            summaryCell(label: "Tokens", value: stats.usage.totalTokens.formattedTokens, color: .blue)
            Divider().frame(height: 32)
            let cacheHitPct = Int(stats.cacheHitRate * 100)
            summaryCell(label: "Cache Hit", value: "\(cacheHitPct)%", color: stats.cacheHitRate > 0.4 ? .green : .orange)
            Divider().frame(height: 32)
            summaryCell(label: "Sessions", value: "\(project.totalSessions)", color: .purple)
        }
        .padding(.vertical, 10)
        .background(.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }

    private func summaryCell(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Meta

    private func metaSection(_ stats: DetailStats) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                metaCell(
                    icon: "clock",
                    label: "Last Active",
                    value: project.lastActivity.map { relativeTime($0) } ?? "—"
                )
                Divider().frame(height: 28)
                metaCell(
                    icon: "person.2",
                    label: "Sub-agents",
                    value: stats.subAgentCount > 0 ? "\(stats.subAgentCount)" : "—"
                )
                Divider().frame(height: 28)
                metaCell(
                    icon: "dollarsign.circle",
                    label: "Avg/Session",
                    value: project.totalSessions > 0
                        ? (stats.usage.costUSD / Double(project.totalSessions)).formattedCost
                        : "—"
                )
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))

            Button(action: { NSWorkspace.shared.open(URL(fileURLWithPath: project.fullPath)) }) {
                HStack(spacing: 4) {
                    Image(systemName: "folder")
                        .font(.system(size: 10))
                        .foregroundStyle(.blue.opacity(0.7))
                    Text(project.fullPath)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.blue.opacity(0.7))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .buttonStyle(.plain)
            .pointerCursor()
        }
    }

    private func metaCell(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.primary)
            }
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func relativeTime(_ date: Date) -> String {
        let diff = Date().timeIntervalSince(date)
        switch diff {
        case ..<60:    return "just now"
        case ..<3600:  return "\(Int(diff / 60))m ago"
        case ..<86400: return "\(Int(diff / 3600))h ago"
        default:       return "\(Int(diff / 86400))d ago"
        }
    }

    // MARK: - Token Mix

    private func tokenMixSection(_ stats: DetailStats) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TOKEN MIX")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            let total = Double(max(stats.usage.totalTokens, 1))
            GeometryReader { geo in
                HStack(spacing: 1) {
                    bar(width: geo.size.width * Double(stats.usage.inputTokens) / total, color: .blue)
                    bar(width: geo.size.width * Double(stats.usage.outputTokens) / total, color: .green)
                    bar(width: geo.size.width * Double(stats.usage.cacheCreationTokens) / total, color: .orange)
                    bar(width: geo.size.width * Double(stats.usage.cacheReadTokens) / total, color: .purple)
                }
                .clipShape(RoundedRectangle(cornerRadius: 3))
            }
            .frame(height: 8)

            HStack(spacing: 0) {
                mixLegend(color: .blue,   label: "Input",   tokens: stats.usage.inputTokens)
                mixLegend(color: .green,  label: "Output",  tokens: stats.usage.outputTokens)
                mixLegend(color: .orange, label: "Cache+",  tokens: stats.usage.cacheCreationTokens)
                mixLegend(color: .purple, label: "Cache↩",  tokens: stats.usage.cacheReadTokens)
            }

            if stats.cacheSavingsUSD > 0 {
                Text("Cache saves ~\(stats.cacheSavingsUSD.formattedCost) vs no caching")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func bar(width: CGFloat, color: Color) -> some View {
        Group {
            if width > 2 {
                Rectangle().fill(color).frame(width: width, height: 8)
            }
        }
    }

    private func mixLegend(color: Color, label: String, tokens: Int) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text("\(label) \(tokens.formattedTokens)")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Models

    private func modelsSection(_ stats: DetailStats) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MODELS")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            let maxCost = stats.models.map(\.cost).max() ?? 1
            VStack(spacing: 7) {
                ForEach(stats.models) { model in
                    HStack(spacing: 8) {
                        Text(model.displayName)
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: 82, alignment: .leading)
                            .lineLimit(1)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2).fill(.blue.opacity(0.12))
                                RoundedRectangle(cornerRadius: 2).fill(.blue)
                                    .frame(width: max(3, geo.size.width * model.cost / maxCost))
                            }
                        }
                        .frame(height: 6)
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(model.cost.formattedCost)
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            Text(model.tokens.formattedTokens)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                        .frame(width: 48)
                    }
                }
            }
        }
    }

    // MARK: - Branches

    private func branchesSection(_ stats: DetailStats) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BRANCHES")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            let maxCost = stats.branches.map(\.cost).max() ?? 1
            VStack(spacing: 7) {
                ForEach(stats.branches.prefix(6)) { branch in
                    BranchRow(branch: branch, maxCost: maxCost)
                }
            }
        }
    }

    // MARK: - Activity

    private var activityData: [Int] {
        switch timeWindow {
        case .today: return project.seriesToday
        case .week:  return project.seriesWeek
        case .month: return project.seriesMonth
        }
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ACTIVITY (\(timeWindow.rawValue.uppercased()))")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            let data = activityData
            if data.max() ?? 0 > 0 {
                ActivityBarChart(data: data, color: projectPalette[project.colorIndex])
                    .frame(height: 56)
                    .padding(.bottom, 4)
            } else {
                Text("No activity")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            }
        }
    }

    // MARK: - Stats computation

    private func computeStats() {
        let now = Date()
        let cutoff: Date
        switch timeWindow {
        case .today: cutoff = Calendar.current.startOfDay(for: now)
        case .week:  cutoff = now.addingTimeInterval(-7 * 86_400)
        case .month: cutoff = now.addingTimeInterval(-30 * 86_400)
        }
        let entries = UsageStore.shared.entries(for: project.id).filter { $0.timestamp >= cutoff }

        guard !entries.isEmpty else {
            stats = DetailStats(usage: .init(), models: [], branches: [], cacheHitRate: 0, subAgentCount: 0, cacheSavingsUSD: 0)
            return
        }

        var totalUsage = TokenUsage()
        var modelMap: [String: TokenUsage] = [:]
        var branchMap: [String: TokenUsage] = [:]
        var subAgentCount = 0
        var cacheSavingsUSD = 0.0

        for entry in entries {
            let p = pricing(for: entry.model)
            let cost = p.cost(
                input: entry.inputTokens, output: entry.outputTokens,
                cacheCreate: entry.cacheCreationTokens, cacheRead: entry.cacheReadTokens
            )
            let eu = TokenUsage(
                inputTokens: entry.inputTokens,
                outputTokens: entry.outputTokens,
                cacheCreationTokens: entry.cacheCreationTokens,
                cacheReadTokens: entry.cacheReadTokens,
                costUSD: cost
            )
            totalUsage += eu
            modelMap[entry.model, default: .init()] += eu
            branchMap[entry.gitBranch ?? "unknown", default: .init()] += eu
            if entry.isSidechain { subAgentCount += 1 }
            // Savings = what cache reads would have cost at input rate minus what they actually cost
            let m = 1_000_000.0
            cacheSavingsUSD += Double(entry.cacheReadTokens) / m * (p.inputPer1M - p.cacheReadPer1M)
        }

        let models = modelMap.map { (model, usage) in
            DetailStats.ModelStat(
                id: model,
                displayName: normalizeModel(model),
                tokens: usage.totalTokens,
                cost: usage.costUSD
            )
        }.sorted { $0.cost > $1.cost }

        let branches = branchMap
            .filter { $0.key != "unknown" }
            .map { DetailStats.BranchStat(id: $0.key, tokens: $0.value.totalTokens, cost: $0.value.costUSD) }
            .sorted { $0.cost > $1.cost }

        let billable = totalUsage.inputTokens + totalUsage.cacheReadTokens
        let cacheHitRate = billable > 0 ? Double(totalUsage.cacheReadTokens) / Double(billable) : 0

        stats = DetailStats(
            usage: totalUsage, models: models, branches: branches,
            cacheHitRate: cacheHitRate, subAgentCount: subAgentCount,
            cacheSavingsUSD: cacheSavingsUSD
        )
    }

    private func normalizeModel(_ model: String) -> String {
        let m = model.lowercased()
        if m.contains("opus-4-7")   { return "Opus 4.7" }
        if m.contains("opus-4-5")   { return "Opus 4.5" }
        if m.contains("opus-4")     { return "Opus 4" }
        if m.contains("opus")       { return "Opus" }
        if m.contains("sonnet-4-6") { return "Sonnet 4.6" }
        if m.contains("sonnet-4-5") { return "Sonnet 4.5" }
        if m.contains("sonnet-3-7") { return "Sonnet 3.7" }
        if m.contains("sonnet-3-5") { return "Sonnet 3.5" }
        if m.contains("sonnet")     { return "Sonnet" }
        if m.contains("haiku-4-5")  { return "Haiku 4.5" }
        if m.contains("haiku-3-5")  { return "Haiku 3.5" }
        if m.contains("haiku")      { return "Haiku" }
        return model
    }
}

// MARK: - Branch row with zero-delay tooltip

private struct BranchRow: View {
    let branch: DetailStats.BranchStat
    let maxCost: Double
    @State private var showTooltip = false

    var body: some View {
        HStack(spacing: 8) {
            Text(branch.id)
                .font(.system(size: 11, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 100, alignment: .leading)
                .onHover { showTooltip = $0 }
                .overlay(alignment: .topLeading) {
                    if showTooltip {
                        Text(branch.id)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(.black.opacity(0.88), in: RoundedRectangle(cornerRadius: 5))
                            .fixedSize()
                            .offset(y: -28)
                            .zIndex(999)
                            .allowsHitTesting(false)
                    }
                }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(.purple.opacity(0.12))
                    RoundedRectangle(cornerRadius: 2).fill(.purple)
                        .frame(width: max(3, geo.size.width * branch.cost / maxCost))
                }
            }
            .frame(height: 6)
            Text(branch.cost.formattedCost)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .frame(width: 48, alignment: .trailing)
        }
    }
}

// MARK: - Supporting types

private struct DetailStats {
    struct ModelStat: Identifiable {
        let id: String
        let displayName: String
        let tokens: Int
        let cost: Double
    }
    struct BranchStat: Identifiable {
        let id: String
        let tokens: Int
        let cost: Double
    }
    let usage: TokenUsage
    let models: [ModelStat]
    let branches: [BranchStat]
    let cacheHitRate: Double
    let subAgentCount: Int
    let cacheSavingsUSD: Double
}

// MARK: - Activity bar chart

private struct ActivityBarChart: View {
    let data: [Int]
    let color: Color

    var body: some View {
        let maxVal = data.max() ?? 1
        GeometryReader { geo in
            HStack(alignment: .bottom, spacing: 1) {
                ForEach(data.indices, id: \.self) { i in
                    let ratio = maxVal > 0 ? CGFloat(data[i]) / CGFloat(maxVal) : 0
                    let barW = max(1, (geo.size.width - CGFloat(data.count - 1)) / CGFloat(data.count))
                    RoundedRectangle(cornerRadius: 1)
                        .fill(ratio > 0 ? color : Color.secondary.opacity(0.08))
                        .frame(width: barW, height: max(1, geo.size.height) * (ratio > 0 ? ratio : 0.04))
                }
            }
        }
    }
}
