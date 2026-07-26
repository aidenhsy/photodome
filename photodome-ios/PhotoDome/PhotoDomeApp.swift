import SwiftUI

@main
struct PhotoDomeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(PhotoDomeTokens.Semantic.textPrimary)
        }
    }
}
