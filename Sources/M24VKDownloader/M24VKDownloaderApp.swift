import AppKit
import SwiftUI

@main
struct M24VKDownloaderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Visible window is owned by AppKit. WindowGroup is intentionally
        // omitted: SwiftPM-packaged apps often never materialize that scene.
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About M24VKDownloader") {
                    AppDelegate.shared?.showAbout()
                }
            }
            CommandGroup(replacing: .appSettings) {}
            CommandGroup(replacing: .newItem) {}
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    static weak var shared: AppDelegate?

    private var mainWindow: NSWindow?
    private var aboutWindow: NSWindow?

    override init() {
        super.init()
        Self.shared = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        DebugLog.rotateLegacyHomebrewLogIfNeeded()
        DebugLog.info("Application launched version \(AppPaths.appVersion) arch=\(HostArchitecture.displayName)")
        showMainWindow()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func showMainWindow() {
        if let window = mainWindow {
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            DebugLog.info("Activated existing main window")
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "M24 VK Downloader"
        window.minSize = NSSize(width: 720, height: 560)
        window.contentView = NSHostingView(rootView: ContentView())
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        window.setFrameAutosaveName("M24VKDownloaderMain")
        mainWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        DebugLog.info("Created main window frame=\(NSStringFromRect(window.frame))")
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender === mainWindow {
            sender.orderOut(nil)
            DebugLog.info("Main window hidden; app stays running")
            return false
        }
        if sender === aboutWindow {
            sender.orderOut(nil)
            return false
        }
        return true
    }

    func showAbout() {
        if let window = aboutWindow {
            window.makeKeyAndOrderFront(nil)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 280),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About M24VKDownloader"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: AboutView())
        window.delegate = self
        window.center()
        aboutWindow = window
        window.makeKeyAndOrderFront(nil)
    }
}
