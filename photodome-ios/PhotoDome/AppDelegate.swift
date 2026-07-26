import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        if identifier == PhotoDownloadManager.sessionIdentifier {
            PhotoDownloadManager.shared.setBackgroundCompletionHandler(
                completionHandler
            )
        } else {
            BackgroundUploadManager.shared.setBackgroundCompletionHandler(
                completionHandler
            )
        }
    }
}
