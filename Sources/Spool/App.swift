import SwiftUI
import AppKit

@main
struct SpoolApp: App {
    @NSApplicationDelegateAdaptor(SpoolAppDelegate.self) var delegate
    @StateObject private var controller = AppController()

    var body: some Scene {
        WindowGroup("Spool") {
            ContentView()
                .environmentObject(controller)
                .frame(minWidth: 760, minHeight: 480)
                .background(Theme.bg)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Spool") {
                    NSApp.orderFrontStandardAboutPanel(options: [
                        .applicationName: "Spool",
                        .credits: NSAttributedString(
                            string: "Open-source macOS macro recorder.\nhttps://github.com/vasilysahrai/spool",
                            attributes: [
                                .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                                .foregroundColor: NSColor.labelColor
                            ]
                        )
                    ])
                }
            }
        }
    }
}

final class SpoolAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
