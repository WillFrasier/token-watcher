import Foundation
import UserNotifications
import TokenWatcherCore

final class AlertsManager: NSObject {
    static let shared = AlertsManager()

    private var alreadyAlerted = Set<String>()

    private override init() { super.init() }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        UNUserNotificationCenter.current().delegate = self
    }

    func checkAlerts(projects: [ProjectUsage]) {
        for project in projects where project.isAlerting {
            guard !alreadyAlerted.contains(project.id) else { continue }
            alreadyAlerted.insert(project.id)
            postNotification(for: project)
        }
        // Clear resolved alerts so they can re-fire next cycle
        let alertingIds = Set(projects.filter(\.isAlerting).map(\.id))
        alreadyAlerted = alreadyAlerted.intersection(alertingIds)
    }

    private func postNotification(for project: ProjectUsage) {
        let content = UNMutableNotificationContent()
        content.title = "Token Watcher: \(project.displayName)"
        content.body = project.alertReason ?? "Unusual activity detected"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "alert-\(project.id)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}

extension AlertsManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
