import SwiftUI

@main
struct PhotoDomeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            rootView
                .tint(PhotoDomeTokens.Semantic.textPrimary)
        }
    }

    @ViewBuilder
    private var rootView: some View {
        #if DEBUG
            if ProcessInfo.processInfo.arguments.contains(
                "PhotoDomeUITestAlbumGridHitTargets"
            ) {
                AlbumGridHitTargetRegressionView()
            } else {
                ContentView()
            }
        #else
            ContentView()
        #endif
    }
}
