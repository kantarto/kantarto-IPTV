import SwiftUI
import AppKit

@main
struct IPTVManagerApp: App {
    @StateObject private var profileStore = ProfileStore()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(profileStore)
                .tint(Color(red: 0.20, green: 0.48, blue: 0.98))
                .preferredColorScheme(.dark)
        }
        .windowResizability(.contentSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
