import SwiftUI

@main
struct MeetCueApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // The app needs a scene, but its windows are AppKit windows, so this one stays empty and its
        // menu item opens the AppKit Settings window.
        Settings { EmptyView() }
            .commands {
                CommandGroup(replacing: .appSettings) {
                    Button("Settings…") { appDelegate.showSettings() }
                        .keyboardShortcut(",")
                }
            }
    }
}
