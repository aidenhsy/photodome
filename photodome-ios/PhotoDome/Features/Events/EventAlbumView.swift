import PhotosUI
import SwiftUI

struct EventAlbumView: View {
    let access: StoredEventAccess
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model: EventAlbumViewModel
    @ObservedObject private var uploads: BackgroundUploadManager
    @ObservedObject private var downloads: PhotoDownloadManager
    @State private var selections: [PhotosPickerItem] = []
    @State private var showsCamera: Bool
    let cameraPresentationRequestID: UUID?
    @State private var photoPendingRemoval: AlbumPhoto?
    @State private var photoPendingRedownload: AlbumPhoto?

    init(
        access: StoredEventAccess,
        initiallyPresentsCamera: Bool = false,
        cameraPresentationRequestID: UUID? = nil,
        onEventSignal: @escaping @MainActor (EventRealtimeSignal) -> Void
    ) {
        self.access = access
        self.cameraPresentationRequestID = cameraPresentationRequestID
        _model = StateObject(
            wrappedValue: EventAlbumViewModel(
                access: access,
                onEventSignal: onEventSignal
            )
        )
        _uploads = ObservedObject(wrappedValue: .shared)
        _downloads = ObservedObject(wrappedValue: .shared)
        _showsCamera = State(initialValue: initiallyPresentsCamera)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: PhotoDomeTokens.Space.x3) {
                Button {
                    showsCamera = true
                } label: {
                    Label("Camera", systemImage: "camera.fill")
                }
                .buttonStyle(AlbumActionButtonStyle(kind: .primary))
                .disabled(!acceptsNewUploads)

                PhotosPicker(
                    selection: $selections,
                    maxSelectionCount: 20,
                    matching: .images,
                    preferredItemEncoding: .current
                ) {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(AlbumActionButtonStyle(kind: .secondary))
                .disabled(!acceptsNewUploads)
            }

            if !acceptsNewUploads {
                Text("The host has closed new uploads.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryInk)
            }

            uploadStatus

            if model.photos.isEmpty, !model.isLoading {
                ContentUnavailableView(
                    "No photos yet",
                    systemImage: "photo.on.rectangle.angled",
                    description: Text(
                        "Add the first photo. Everyone in the event will see it when processing finishes."
                    )
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(
                            .flexible(),
                            spacing: PhotoDomeTokens.Space.x1
                        ),
                        GridItem(
                            .flexible(),
                            spacing: PhotoDomeTokens.Space.x1
                        ),
                        GridItem(
                            .flexible(),
                            spacing: PhotoDomeTokens.Space.x1
                        ),
                    ],
                    spacing: PhotoDomeTokens.Space.x1
                ) {
                    ForEach(model.photos) { photo in
                        AlbumGridCell(photoID: photo.id) {
                            handlePhotoTap(photo)
                        } label: {
                            ZStack {
                                AlbumThumbnail(url: photo.thumbnailURL) {
                                    Task {
                                        await model
                                            .recoverMediaURLAfterFailure(
                                                photo.thumbnailURL
                                            )
                                    }
                                }

                                VStack {
                                    Spacer()
                                    HStack(alignment: .bottom) {
                                        photoBadges(photo)
                                        Spacer(minLength: 0)
                                        quickDownloadIndicator(photo)
                                    }
                                }
                                .padding(6)
                            }
                        }
                        .contextMenu {
                            photoActions(photo)
                        }
                        .accessibilityHint(accessibilityHint(for: photo))
                    }
                }
            }
        }
        .task {
            await model.bootstrap()
            await downloads.configure()
        }
        .fullScreenCover(isPresented: $showsCamera) {
            EventCameraView(eventName: model.access.event.name) {
                data,
                capturedAt,
                captureLocation,
                isNewCapture in
                Task {
                    await model.addPhoto(
                        data: data,
                        capturedAt: capturedAt,
                        captureLocation: captureLocation,
                        saveToLibrary: isNewCapture
                    )
                }
            }
        }
        .onDisappear { model.disconnect() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task {
                    await model.refreshMediaURLsIfNeeded()
                }
            }
        }
        .onChange(of: access) { _, newAccess in
            model.updateAccess(newAccess)
        }
        .onChange(of: cameraPresentationRequestID) { _, requestID in
            if requestID != nil, acceptsNewUploads {
                showsCamera = true
            }
        }
        .onChange(of: selections) { _, newSelections in
            selections = []
            Task {
                for selection in newSelections {
                    guard
                        let data = try? await selection.loadTransferable(
                            type: Data.self
                        )
                    else {
                        continue
                    }
                    await model.addPhoto(data: data)
                }
            }
        }
        .alert(
            "PhotoDome couldn’t finish that",
            isPresented: Binding(
                get: { model.presentedError != nil },
                set: { if !$0 { model.presentedError = nil } }
            )
        ) {
            Button("OK") { model.presentedError = nil }
        } message: {
            Text(model.presentedError ?? "")
        }
        .confirmationDialog(
            "Delete this photo?",
            isPresented: Binding(
                get: { photoPendingRemoval != nil },
                set: { if !$0 { photoPendingRemoval = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete photo", role: .destructive) {
                guard let photo = photoPendingRemoval else { return }
                photoPendingRemoval = nil
                Task { await model.removePhoto(photo.id) }
            }
            Button("Cancel", role: .cancel) {
                photoPendingRemoval = nil
            }
        } message: {
            Text(
                "It disappears for everyone and is permanently deleted."
            )
        }
        .confirmationDialog(
            "Download this photo again?",
            isPresented: Binding(
                get: { photoPendingRedownload != nil },
                set: { if !$0 { photoPendingRedownload = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Download again") {
                guard let photo = photoPendingRedownload else { return }
                photoPendingRedownload = nil
                Task { await download(photo, again: true) }
            }
            Button("Cancel", role: .cancel) {
                photoPendingRedownload = nil
            }
        } message: {
            Text("This adds another copy to your Photos library.")
        }
    }

    @ViewBuilder
    private func photoActions(_ photo: AlbumPhoto) -> some View {
        let isYours =
            photo.contributorMemberID == model.access.event.memberID
        let isSaved = downloads.savedPhotoIDs(eventID: model.access.id)
            .contains(photo.id)

        if model.access.event.state != .expiring {
            if isYours || isSaved {
                Button {
                    photoPendingRedownload = photo
                } label: {
                    Label(
                        "Download again",
                        systemImage: "square.and.arrow.down"
                    )
                }
            } else {
                Button {
                    Task { await download(photo, again: false) }
                } label: {
                    Label("Download", systemImage: "square.and.arrow.down")
                }
            }
        }

        if isYours {
            Button(role: .destructive) {
                photoPendingRemoval = photo
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func download(_ photo: AlbumPhoto, again: Bool) async {
        do {
            try await downloads.start(
                photoID: photo.id,
                access: model.access,
                downloadAgain: again
            )
        } catch {
            model.presentedError = error.photoDomeMessage
        }
    }

    private func handlePhotoTap(_ photo: AlbumPhoto) {
        guard model.access.event.state != .expiring else { return }

        let isYours =
            photo.contributorMemberID == model.access.event.memberID
        let isSaved = downloads.savedPhotoIDs(eventID: model.access.id)
            .contains(photo.id)
        let isDownloading = downloads.items.contains {
            $0.eventID == model.access.id
                && $0.photoID == photo.id
                && [.queued, .downloading, .saving].contains($0.state)
        }

        guard !isDownloading else { return }
        if isYours || isSaved {
            photoPendingRedownload = photo
        } else {
            Task { await download(photo, again: false) }
        }
    }

    @ViewBuilder
    private func quickDownloadIndicator(_ photo: AlbumPhoto) -> some View {
        let isYours =
            photo.contributorMemberID == model.access.event.memberID
        let isSaved = downloads.savedPhotoIDs(eventID: model.access.id)
            .contains(photo.id)
        let activeDownload = downloads.items.last {
            $0.eventID == model.access.id
                && $0.photoID == photo.id
                && [.queued, .downloading, .saving].contains($0.state)
        }

        if !isYours, !isSaved, model.access.event.state != .expiring {
            if activeDownload != nil {
                ProgressView()
                    .tint(.white)
                    .frame(width: 36, height: 36)
                    .background(.black.opacity(0.72), in: Circle())
                    .frame(width: 44, height: 44)
                    .accessibilityLabel("Downloading photo")
            } else {
                Image(systemName: "arrow.down")
                    .font(.system(.footnote, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.black.opacity(0.72), in: Circle())
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)
            }
        }
    }

    private func accessibilityHint(for photo: AlbumPhoto) -> String {
        let isYours =
            photo.contributorMemberID == model.access.event.memberID
        let isSaved = downloads.savedPhotoIDs(eventID: model.access.id)
            .contains(photo.id)

        if isYours || isSaved {
            return "Tap to download another copy. Long press for photo actions."
        }
        return "Tap to save this photo. Long press for photo actions."
    }

    private var acceptsNewUploads: Bool {
        model.access.event.state != .expiring
            && model.access.event.uploadsRestrictedAt == nil
    }

    @ViewBuilder
    private func photoBadges(_ photo: AlbumPhoto) -> some View {
        let isYours =
            photo.contributorMemberID == model.access.event.memberID
        let isSaved = downloads.savedPhotoIDs(eventID: model.access.id)
            .contains(photo.id)

        if isYours || isSaved {
            if isYours {
                PhotoStatusBadge(title: "Yours", systemImage: "person.fill")
            } else if isSaved {
                PhotoStatusBadge(
                    title: "Saved",
                    systemImage: "checkmark"
                )
            }
        }
    }

    @ViewBuilder
    private var uploadStatus: some View {
        let eventUploads = uploads.items.filter {
            $0.eventID == model.access.id
        }
        if !eventUploads.isEmpty {
            VStack(spacing: 10) {
                ForEach(eventUploads) { item in
                    HStack(spacing: 12) {
                        Image(systemName: icon(for: item.state))
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(label(for: item.state))
                                .font(
                                    .system(
                                        .subheadline,
                                        design: .rounded,
                                        weight: .semibold
                                    )
                                )
                            if item.state == .uploading {
                                ProgressView(value: item.progress)
                                    .tint(AppTheme.ink)
                                    .accessibilityLabel("Upload progress")
                                    .accessibilityValue(
                                        "\(Int(item.progress * 100)) percent"
                                    )
                            } else if let failure = item.failureMessage {
                                Text(failure)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.secondaryInk)
                            }
                        }
                        Spacer()
                        if item.state == .failed {
                            Button("Retry") {
                                Task {
                                    await uploads.retry(itemID: item.id)
                                }
                            }
                            .buttonStyle(.bordered)
                            .tint(AppTheme.ink)
                        }
                    }
                }
            }
            .padding(14)
            .background(AppTheme.softFill)
            .clipShape(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
            )
        }
    }

    private func label(for state: UploadQueueState) -> String {
        switch state {
        case .uploading: "Uploading"
        case .verifying: "Verifying"
        case .processing: "Preparing for the album"
        case .failed: "Upload needs attention"
        }
    }

    private func icon(for state: UploadQueueState) -> String {
        switch state {
        case .uploading: "arrow.up.circle"
        case .verifying: "checkmark.shield"
        case .processing: "wand.and.stars"
        case .failed: "exclamationmark.circle"
        }
    }
}

struct AlbumGridCell<Label: View>: View {
    let photoID: String
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        Button(action: action) {
            label()
                // `scaledToFill` content keeps its oversized interaction
                // region even when its pixels are clipped. Constrain every
                // album button to its visible grid cell so a neighboring
                // photo cannot intercept taps near a row boundary.
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("albumPhoto.\(photoID)")
    }
}

#if DEBUG
    struct AlbumGridHitTargetRegressionView: View {
        @State private var lastTappedPhoto = "none"

        var body: some View {
            VStack(spacing: 16) {
                Text("Tapped \(lastTappedPhoto)")
                    .accessibilityIdentifier("albumGridTapResult")

                LazyVGrid(
                    columns: [GridItem(.fixed(180))],
                    spacing: PhotoDomeTokens.Space.x1
                ) {
                    regressionCell(photoID: "top", symbol: "rectangle.portrait.fill")
                    regressionCell(photoID: "bottom", symbol: "rectangle.landscape.fill")
                }
            }
            .padding()
        }

        private func regressionCell(
            photoID: String,
            symbol: String
        ) -> some View {
            AlbumGridCell(photoID: photoID) {
                lastTappedPhoto = photoID
            } label: {
                Color.clear
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        Image(systemName: symbol)
                            .resizable()
                            .scaledToFill()
                    }
                    .clipShape(Rectangle())
            }
        }
    }
#endif

private struct PhotoStatusBadge: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.system(.caption2, design: .rounded, weight: .bold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(.black.opacity(0.72), in: Capsule())
    }
}

private enum AlbumActionKind {
    case primary
    case secondary
}

private struct AlbumActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    let kind: AlbumActionKind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(
                .system(
                    .title3,
                    design: .rounded,
                    weight: .semibold
                )
            )
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(minHeight: PhotoDomeTokens.Space.x16)
            .background(background(configuration: configuration))
            .overlay {
                if kind == .secondary {
                    RoundedRectangle(
                        cornerRadius: PhotoDomeTokens.Radius.default,
                        style: .continuous
                    )
                    .stroke(PhotoDomeTokens.Semantic.borderSubtle)
                }
            }
            .clipShape(
                RoundedRectangle(
                    cornerRadius: PhotoDomeTokens.Radius.default,
                    style: .continuous
                )
            )
            .opacity(isEnabled ? 1 : 0.38)
    }

    private var foreground: Color {
        switch kind {
        case .primary:
            PhotoDomeTokens.Semantic.actionPrimaryLabel
        case .secondary:
            PhotoDomeTokens.Semantic.textPrimary
        }
    }

    private func background(configuration: Configuration) -> Color {
        switch kind {
        case .primary:
            PhotoDomeTokens.Semantic.actionPrimaryBackground.opacity(
                configuration.isPressed ? 0.72 : 1
            )
        case .secondary:
            configuration.isPressed
                ? PhotoDomeTokens.Semantic.backgroundRaised
                : PhotoDomeTokens.Semantic.backgroundPrimary
        }
    }
}

private struct AlbumThumbnail: View {
    let url: URL
    let onLoadFailure: () -> Void

    var body: some View {
        Rectangle()
            .fill(AppTheme.softFill)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        Image(systemName: "photo")
                            .foregroundStyle(AppTheme.secondaryInk)
                            .onAppear(perform: onLoadFailure)
                    default:
                        ProgressView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .clipped()
            .accessibilityLabel("Event photo")
    }
}
