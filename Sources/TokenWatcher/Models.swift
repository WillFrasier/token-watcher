import Foundation
import Combine
import TokenWatcherCore

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
