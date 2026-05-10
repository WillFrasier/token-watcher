import SwiftUI

struct SettingsView: View {
    let onBack: () -> Void
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var store = UsageStore.shared

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    alertsSection
                    refreshSection
                    displaySection
                    dataSection
                    footerRow
                }
                .padding(14)
            }
        }
        .frame(width: 340, height: 580)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
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
            Text("Settings")
                .font(.system(size: 13, weight: .semibold))
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

    // MARK: - Alerts

    private var alertsSection: some View {
        SettingsCard(title: "ALERTS") {
            // Cost threshold
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cost alert / hour")
                            .font(.system(size: 13, weight: .medium))
                        Text("Alert when a project exceeds this in the last hour")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(settings.costAlertThreshold.formattedCost)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.orange)
                        .frame(width: 52, alignment: .trailing)
                }
                TrackSlider(
                    value: $settings.costAlertThreshold,
                    range: 0.5...50.0,
                    step: 0.5,
                    color: .orange
                )
                HStack {
                    Text("$0.50")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Text("$50")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }

            Divider().padding(.vertical, 10)

            // Session threshold
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Session count alert")
                        .font(.system(size: 13, weight: .medium))
                    Text("Sessions active in the last hour")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Stepper(value: $settings.subAgentAlertThreshold, in: 2...20) {
                    Text("\(settings.subAgentAlertThreshold)")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .frame(width: 24, alignment: .trailing)
                }
                .fixedSize()
            }
        }
    }

    // MARK: - Refresh

    private var refreshSection: some View {
        SettingsCard(title: "REFRESH") {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Update interval")
                        .font(.system(size: 13, weight: .medium))
                    Text("How often to re-read usage data")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Picker("", selection: $settings.updateIntervalSeconds) {
                    Text("30s").tag(30)
                    Text("1 min").tag(60)
                    Text("2 min").tag(120)
                    Text("5 min").tag(300)
                }
                .labelsHidden()
                .frame(width: 84)
                .onChange(of: settings.updateIntervalSeconds) { _ in
                    store.setupTimer()
                    NotificationCenter.default.post(name: .settingsDidChange, object: nil)
                }
            }
        }
    }

    // MARK: - Display

    private var displaySection: some View {
        SettingsCard(title: "DISPLAY") {
            HStack(alignment: .top, spacing: 10) {
                Toggle("", isOn: $settings.hideInactiveProjects)
                    .labelsHidden()
                    .onChange(of: settings.hideInactiveProjects) { _ in
                        Task { await store.refresh() }
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hide inactive projects")
                        .font(.system(size: 13, weight: .medium))
                    Text("Only show projects with activity in the selected window")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
        }
    }

    // MARK: - Data

    private var dataSection: some View {
        SettingsCard(title: "DATA") {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Projects directory")
                        .font(.system(size: 13, weight: .medium))
                    Text(UsageParser.projectsURL.path)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button("Reveal") {
                    NSWorkspace.shared.open(UsageParser.projectsURL)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    // MARK: - Footer

    private var footerRow: some View {
        HStack {
            Button("Reset Defaults") {
                settings.reset()
                store.setupTimer()
            }
            .foregroundStyle(.red)
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .pointerCursor()

            Spacer()

            Button {
                Task { await store.refresh() }
            } label: {
                Label("Refresh Now", systemImage: "arrow.clockwise")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }
}

// MARK: - Custom track slider (macOS NSSlider doesn't fill the track on the left)

private struct TrackSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let filled = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound)) * w
            let thumbX = filled.clamped(to: 8...(w - 8))

            ZStack(alignment: .leading) {
                // Track background
                Capsule()
                    .fill(Color.secondary.opacity(0.18))
                    .frame(height: 4)
                // Filled portion
                Capsule()
                    .fill(color)
                    .frame(width: filled, height: 4)
                // Thumb
                Circle()
                    .fill(Color(nsColor: .controlColor))
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    .frame(width: 16, height: 16)
                    .offset(x: thumbX - 8)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let ratio = (drag.location.x / w).clamped(to: 0...1)
                        let raw = range.lowerBound + ratio * (range.upperBound - range.lowerBound)
                        let stepped = (raw / step).rounded() * step
                        value = stepped.clamped(to: range.lowerBound...range.upperBound)
                    }
            )
        }
        .frame(height: 16)
        .pointerCursor()
    }
}

// MARK: - Card

private struct SettingsCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.4)

            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
