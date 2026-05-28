import AppKit

private let app = NSApplication.shared

UserDefaultsMigration.migrateIfNeeded()
Config.shared.resolveGestureFingerConflicts()

let accessibilityMonitor = AccessibilityMonitor()

let controller = Controller()
controller.start()

let trayMenu = TrayMenu()
#if DEBUG
trayMenu.restartListeners = controller.restartListeners
#endif

accessibilityMonitor.start()

app.delegate = trayMenu

app.run()
