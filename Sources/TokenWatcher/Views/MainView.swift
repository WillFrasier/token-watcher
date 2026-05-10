import SwiftUI

struct MainView: View {
    @ObservedObject private var store = UsageStore.shared
    @ObservedObject private var settings = AppSettings.shared

    @State private var selectedProject: ProjectUsage? = nil
    @State private var showSettings = false

    var body: some View {
        if let project = selectedProject {
            ProjectDetailView(
                project: project,
                timeWindow: settings.timeWindow,
                onBack: { selectedProject = nil }
            )
        } else if showSettings {
            SettingsView(onBack: { showSettings = false })
        } else {
            mainContent
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            headerBar
            chartBar
            summaryBar
            Divider().opacity(0.4)
            projectList
            Divider().opacity(0.4)
            footerBar
        }
        .frame(width: 340)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Header (2-row: title row + time picker row)

    private var headerBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(.blue)
                    .font(.system(size: 14, weight: .semibold))
                Text("Token Watcher")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Spacer()
                Button(action: { Task { await store.refresh() } }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .opacity(store.isLoading ? 0.4 : 1)
                }
                .buttonStyle(.plain)
                .disabled(store.isLoading)
                .pointerCursor()

                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .pointerCursor()
            }

            Picker("", selection: $settings.timeWindow) {
                ForEach(TimeWindow.allCases) { window in
                    Text(window.rawValue).tag(window)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    // MARK: - Chart

    private var chartBar: some View {
        let series = visibleProjects.prefix(8).map { p -> TokenChartView.ProjectSeries in
            let data: [Int]
            let costData: [Double]
            switch settings.timeWindow {
            case .today: data = p.seriesToday;  costData = p.costSeriesToday
            case .week:  data = p.seriesWeek;   costData = p.costSeriesWeek
            case .month: data = p.seriesMonth;  costData = p.costSeriesMonth
            }
            return TokenChartView.ProjectSeries(data: data, costData: costData, color: projectPalette[p.colorIndex])
        }
        return TokenChartView(series: Array(series))
            .frame(height: 80)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.black.opacity(0.06))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(.white.opacity(0.10), lineWidth: 0.5)
                    }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
    }

    // MARK: - Summary

    private var summaryBar: some View {
        let total = store.totalForWindow(settings.timeWindow)
        let alertCount = store.projects.filter(\.isAlerting).count
        return HStack(spacing: 0) {
            summaryItem(label: "Tokens", value: total.totalTokens.formattedTokens, icon: "bolt.fill", color: .blue)
            summaryDivider
            summaryItem(label: "Cost", value: total.costUSD.formattedCost, icon: "dollarsign.circle.fill", color: .green)
            summaryDivider
            summaryItem(label: "Projects", value: "\(store.projects.count)", icon: "folder.fill", color: .purple)
            if alertCount > 0 {
                summaryDivider
                summaryItem(label: "Alerts", value: "\(alertCount)", icon: "exclamationmark.triangle.fill", color: .orange)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(.black.opacity(0.06))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(.white.opacity(0.10), lineWidth: 0.5)
                }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var summaryDivider: some View {
        Divider().frame(height: 28).padding(.horizontal, 8)
    }

    private func summaryItem(label: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.system(size: 11))
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .lineLimit(1)
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Project List

    private var projectList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if store.projects.isEmpty && !store.isLoading {
                    emptyState
                } else {
                    ForEach(visibleProjects) { project in
                        ProjectRowView(
                            project: project,
                            usage: store.usageForWindow(settings.timeWindow, project: project),
                            maxTokens: maxTokensForWindow
                        )
                        .pointerCursor()
                        .onTapGesture {
                            selectedProject = project
                        }
                        if project.id != visibleProjects.last?.id {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
            }
        }
        .frame(maxHeight: 260)
    }

    private var visibleProjects: [ProjectUsage] {
        store.projects
            .filter { store.usageForWindow(settings.timeWindow, project: $0).totalTokens > 0 }
            .sorted { store.usageForWindow(settings.timeWindow, project: $0).totalTokens > store.usageForWindow(settings.timeWindow, project: $1).totalTokens }
    }

    private var maxTokensForWindow: Int {
        visibleProjects.map {
            store.usageForWindow(settings.timeWindow, project: $0).totalTokens
        }.max() ?? 1
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text("No usage data found")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Text("~/.claude/projects/")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack {
            if let error = store.loadError {
                Image(systemName: "exclamationmark.circle").foregroundStyle(.red).font(.system(size: 10))
                Text(error).font(.system(size: 10)).foregroundStyle(.red).lineLimit(1)
            } else if let updated = store.lastUpdated {
                Image(systemName: "clock").foregroundStyle(.tertiary).font(.system(size: 10))
                Text("Updated \(updated, style: .relative) ago")
                    .font(.system(size: 10)).foregroundStyle(.tertiary)
            }
            Spacer()
            Text("Every \(AppSettings.shared.updateIntervalSeconds)s")
                .font(.system(size: 10)).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}
