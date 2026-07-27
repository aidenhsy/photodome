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
            } else if ProcessInfo.processInfo.arguments.contains(
                "PhotoDomeUITestEventArchive"
            ) {
                EventArchiveRegressionView()
            } else if ProcessInfo.processInfo.arguments.contains(
                "PhotoDomeUITestInviteCodeCopy"
            ) {
                InviteCodeCopyRegressionView()
            } else if ProcessInfo.processInfo.arguments.contains(
                "PhotoDomeUITestHostTransfer"
            ) {
                HostTransferRegressionView()
            } else if ProcessInfo.processInfo.arguments.contains(
                "PhotoDomeUITestAttendeeList"
            ) {
                AttendeeListRegressionView()
            } else if ProcessInfo.processInfo.arguments.contains(
                "PhotoDomeUITestCameraControls"
            ) {
                CameraControlsRegressionView()
            } else {
                ContentView()
            }
        #else
            ContentView()
        #endif
    }
}
