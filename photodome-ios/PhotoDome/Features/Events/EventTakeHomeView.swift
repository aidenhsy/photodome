import SwiftUI
import UIKit

struct EventTakeHomeView: View {
    let access: StoredEventAccess
    @ObservedObject private var downloads = PhotoDownloadManager.shared
    @State private var showsReview = false
    @State private var isStartingAll = false
    @State private var presentedError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Button {
                    showsReview = true
                } label: {
                    actionLabel(
                        "Choose photos",
                        systemImage: "hand.draw"
                    )
                }
                .buttonStyle(OutlineButtonStyle())

                Button {
                    Task { await saveAll() }
                } label: {
                    if isStartingAll {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        actionLabel(
                            EventTakeHomePolicy.saveAllLabel(
                                for: access.event.state
                            ),
                            systemImage: "square.and.arrow.down"
                        )
                    }
                }
                .buttonStyle(MonochromeButtonStyle())
                .disabled(isStartingAll)
            }

            downloadStatus
        }
        .task { await downloads.configure() }
        .sheet(isPresented: $showsReview) {
            PhotoReviewView(access: access)
        }
        .alert(
            "PhotoDome couldn’t start saving",
            isPresented: Binding(
                get: { presentedError != nil },
                set: { if !$0 { presentedError = nil } }
            )
        ) {
            Button("OK") { presentedError = nil }
        } message: {
            Text(presentedError ?? "")
        }
    }

    private func actionLabel(
        _ title: String,
        systemImage: String
    ) -> some View {
        ViewThatFits(in: .horizontal) {
            Label(title, systemImage: systemImage)
                .fixedSize(horizontal: true, vertical: false)

            Text(title)
                .fixedSize(horizontal: true, vertical: false)

            Text(title)
                .font(
                    .system(
                        .subheadline,
                        design: .rounded,
                        weight: .semibold
                    )
                )
                .minimumScaleFactor(0.65)
        }
        .lineLimit(1)
        .allowsTightening(true)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }

    @ViewBuilder
    private var downloadStatus: some View {
        let eventItems = downloads.items.filter { $0.eventID == access.id }
        if !eventItems.isEmpty {
            let savedCount = eventItems.filter { $0.state == .saved }.count
            let failed = eventItems.filter { $0.state == .failed }
            let active = eventItems.filter {
                [.queued, .downloading, .saving].contains($0.state)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("\(savedCount) saved")
                    Spacer()
                    if !active.isEmpty {
                        Text("\(active.count) in progress")
                    } else if !failed.isEmpty {
                        Text("\(failed.count) need attention")
                    }
                }
                .font(.system(.subheadline, design: .rounded, weight: .semibold))

                ForEach(active.prefix(3)) { item in
                    HStack {
                        Text(label(for: item.state))
                            .font(.caption)
                        Spacer()
                        if item.state == .downloading {
                            ProgressView(value: item.progress)
                                .frame(width: 100)
                                .tint(AppTheme.ink)
                        } else {
                            ProgressView()
                        }
                    }
                }

                ForEach(failed) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.failureMessage ?? "This photo needs attention.")
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryInk)
                        HStack {
                            Button("Retry") {
                                Task { await downloads.retry(itemID: item.id) }
                            }
                            .buttonStyle(.bordered)
                            .tint(AppTheme.ink)

                            if item.failureMessage?.contains("Settings") == true {
                                Button("Open Settings") {
                                    guard
                                        let url = URL(
                                            string: UIApplication
                                                .openSettingsURLString
                                        )
                                    else {
                                        return
                                    }
                                    UIApplication.shared.open(url)
                                }
                                .buttonStyle(.bordered)
                                .tint(AppTheme.ink)
                            }
                        }
                    }
                }
            }
        }
    }

    private func saveAll() async {
        isStartingAll = true
        defer { isStartingAll = false }
        do {
            try await downloads.start(mode: .all, access: access)
        } catch {
            presentedError = error.photoDomeMessage
        }
    }

    private func label(for state: PhotoDownloadState) -> String {
        switch state {
        case .queued: "Waiting"
        case .downloading: "Downloading original"
        case .saving: "Adding to Photos"
        case .saved: "Saved"
        case .failed: "Needs attention"
        }
    }

}

enum EventTakeHomePolicy {
    static func isAvailable(for event: EventSnapshot) -> Bool {
        guard (event.readyPhotoCount ?? 0) > 0 else { return false }
        return event.state == .live || event.state == .ended
    }

    static func saveAllLabel(for lifecycle: EventLifecycle) -> String {
        lifecycle == .live ? "Save current photos" : "Save all"
    }
}
