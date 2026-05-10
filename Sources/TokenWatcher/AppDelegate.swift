import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController()
        AlertsManager.shared.requestPermission()
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusBarController = nil
    }
}
