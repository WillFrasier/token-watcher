import SwiftUI
import TokenWatcherCore

struct ProjectRowView: View {
    let project: ProjectUsage
    let usage: TokenUsage
    let maxTokens: Int

    var body: some View {
        HStack(spacing: 10) {
            projectIcon
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(project.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Text(usage.costUSD.formattedCost)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(usage.costUSD > 1 ? .primary : .secondary)
                }
                progressBar
                HStack(spacing: 8) {
                    tokenLabel
                    if project.subAgentCount > 0 { subAgentBadge }
                    if project.recentSessions > 1 { sessionBadge }
                    Spacer()
                    if project.isAlerting { alertBadge }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(project.isAlerting ? Color.orange.opacity(0.05) : .clear)
        .contentShape(Rectangle())
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(projectPalette[project.colorIndex])
                .frame(width: 3)
        }
    }

    private var projectIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(iconColor.opacity(0.15))
                .frame(width: 30, height: 30)
            Image(systemName: iconName)
                .font(.system(size: 13))
                .foregroundStyle(iconColor)
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(.quaternary)
                    .frame(height: 4)
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor)
                    .frame(
                        width: max(4, geo.size.width * Double(usage.totalTokens) / Double(max(maxTokens, 1))),
                        height: 4
                    )
            }
        }
        .frame(height: 4)
    }

    private var tokenLabel: some View {
        Text(usage.totalTokens.formattedTokens)
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(.secondary)
    }

    private var subAgentBadge: some View {
        Label("\(project.subAgentCount)", systemImage: "arrow.triangle.branch")
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(.blue)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(.blue.opacity(0.12), in: Capsule())
    }

    private var sessionBadge: some View {
        Label("\(project.recentSessions) recent", systemImage: "clock")
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(.purple)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(.purple.opacity(0.12), in: Capsule())
    }

    private var alertBadge: some View {
        Label(project.alertReason ?? "Alert", systemImage: "exclamationmark.triangle.fill")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.orange)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(.orange.opacity(0.15), in: Capsule())
    }

    private var iconName: String {
        let path = project.fullPath.lowercased()
        if path.contains("git") || path.contains("src") { return "terminal.fill" }
        if path.contains("drive") || path.contains("cloud") { return "cloud.fill" }
        if path.contains("document") { return "doc.fill" }
        return "folder.fill"
    }

    private var paletteColor: Color { projectPalette[project.colorIndex] }

    private var iconColor: Color {
        project.isAlerting ? .orange : paletteColor
    }

    private var barColor: Color {
        project.isAlerting ? .orange : paletteColor
    }
}
