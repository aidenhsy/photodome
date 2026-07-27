import PhotosUI
import SwiftUI

struct EventAlbumView: View {
    let access: StoredEventAccess
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model: EventAlbumViewModel
    @ObservedObject private var uploads: BackgroundUploadManager
    @ObservedObject private var downloads: PhotoDownloadManager
    @State private var selections: [PhotosPickerItem] = []
    @State private var preparingUploads: [PreparingAlbumPhoto] = []
    @State private var showsCamera: Bool
    let cameraPresentationRequestID: UUID?
    @State private var photoConfirmation: AlbumPhotoConfirmation?

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

            if !hasAlbumContent, !model.isLoading {
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
                    ForEach(visiblePreparingUploads) { photo in
                        PreparingPhotoGridCell(photo: photo)
                    }

                    ForEach(visibleEventUploads) { item in
                        UploadPhotoGridCell(item: item) {
                            Task {
                                await uploads.retry(itemID: item.id)
                            }
                        }
                    }

                    ForEach(model.photos) { photo in
                        AlbumGridCell(photoID: photo.id) {
                            handlePhotoTap(photo)
                        } label: {
                            ZStack {
                                AlbumThumbnail(
                                    eventID: model.access.id,
                                    photo: photo,
                                    eventExpiresAt:
                                        AlbumMediaURLRefreshPolicy.date(
                                            model.access.event.expiresAt
                                        )
                                ) {
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
                        .task {
                            await model.photoBecameVisible(photo.id)
                        }
                        .contextMenu {
                            photoActions(photo)
                        }
                        .confirmationDialog(
                            photoConfirmationTitle,
                            isPresented: confirmationBinding(for: photo),
                            titleVisibility: .visible
                        ) {
                            photoConfirmationActions(for: photo)
                        } message: {
                            Text(photoConfirmationMessage)
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
                startOptimisticUpload(
                    data: data,
                    capturedAt: capturedAt,
                    captureLocation: captureLocation,
                    saveToLibrary: isNewCapture
                )
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
                    startOptimisticUpload(data: data)
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
    }

    private func confirmationBinding(for photo: AlbumPhoto) -> Binding<Bool> {
        Binding(
            get: { photoConfirmation?.photoID == photo.id },
            set: { isPresented in
                if !isPresented, photoConfirmation?.photoID == photo.id {
                    photoConfirmation = nil
                }
            }
        )
    }

    private var photoConfirmationTitle: String {
        switch photoConfirmation {
        case .removal:
            "Delete this photo?"
        case .redownload:
            "Download this photo again?"
        case nil:
            ""
        }
    }

    private var photoConfirmationMessage: String {
        switch photoConfirmation {
        case .removal:
            "It disappears for everyone and is permanently deleted."
        case .redownload:
            "This adds another copy to your Photos library."
        case nil:
            ""
        }
    }

    @ViewBuilder
    private func photoConfirmationActions(for photo: AlbumPhoto) -> some View {
        switch photoConfirmation {
        case .removal:
            Button("Delete photo", role: .destructive) {
                photoConfirmation = nil
                Task { await model.removePhoto(photo.id) }
            }
        case .redownload:
            Button("Download again") {
                photoConfirmation = nil
                Task { await download(photo, again: true) }
            }
        case nil:
            EmptyView()
        }

        Button("Cancel", role: .cancel) {
            photoConfirmation = nil
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
                    photoConfirmation = .redownload(photo)
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
                photoConfirmation = .removal(photo)
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
            photoConfirmation = .redownload(photo)
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

    private var eventQueueItems: [UploadQueueItem] {
        uploads.items.filter { $0.eventID == model.access.id }
    }

    private var visibleEventUploads: [UploadQueueItem] {
        AlbumUploadGridPolicy.visibleQueueItems(
            eventID: model.access.id,
            readyPhotoIDs: Set(model.photos.map(\.id)),
            allItems: uploads.items
        )
    }

    private var visiblePreparingUploads: [PreparingAlbumPhoto] {
        let visibleIDs = AlbumUploadGridPolicy.visiblePreparingIDs(
            preparingUploads.map(\.id),
            eventQueueItems: eventQueueItems
        )
        let photosByID = Dictionary(
            uniqueKeysWithValues: preparingUploads.map { ($0.id, $0) }
        )
        return visibleIDs.compactMap {
            photosByID[$0]
        }
    }

    private var hasAlbumContent: Bool {
        !model.photos.isEmpty
            || !visibleEventUploads.isEmpty
            || !visiblePreparingUploads.isEmpty
    }

    private func startOptimisticUpload(
        data: Data,
        capturedAt: Date? = nil,
        captureLocation: PhotoCaptureLocation? = nil,
        saveToLibrary: Bool = false
    ) {
        let uploadID = UUID()
        preparingUploads.append(
            PreparingAlbumPhoto(id: uploadID, image: nil)
        )

        Task {
            async let thumbnail = LocalImageThumbnailer.make(data: data)
            async let accepted = model.addPhoto(
                data: data,
                capturedAt: capturedAt,
                captureLocation: captureLocation,
                saveToLibrary: saveToLibrary,
                uploadID: uploadID
            )
            if let image = await thumbnail,
                let index = preparingUploads.firstIndex(where: {
                    $0.id == uploadID
                })
            {
                preparingUploads[index].image = image
            }
            _ = await accepted
            preparingUploads.removeAll { $0.id == uploadID }
        }
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
}

private enum AlbumPhotoConfirmation {
    case removal(AlbumPhoto)
    case redownload(AlbumPhoto)

    var photoID: String {
        switch self {
        case .removal(let photo), .redownload(let photo):
            photo.id
        }
    }
}

private struct PreparingAlbumPhoto: Identifiable {
    let id: UUID
    var image: UIImage?
}

private struct PreparingPhotoGridCell: View {
    let photo: PreparingAlbumPhoto

    var body: some View {
        ZStack {
            if let image = photo.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Rectangle()
                    .fill(AppTheme.softFill)
            }

            UploadPhotoOverlay(state: nil)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Photo preparing to upload")
        .accessibilityIdentifier("albumUpload.\(photo.id.uuidString)")
    }
}

private struct UploadPhotoGridCell: View {
    let item: UploadQueueItem
    let retry: () -> Void

    @ViewBuilder
    var body: some View {
        if item.state == .failed {
            Button(action: retry) {
                content
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint("Tap to retry this upload.")
            .accessibilityIdentifier(
                "albumUpload.\(item.id.uuidString)"
            )
        } else {
            content
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityLabel)
                .accessibilityHint(
                    "The photo will become available when processing finishes."
                )
                .accessibilityIdentifier(
                    "albumUpload.\(item.id.uuidString)"
                )
        }
    }

    private var content: some View {
        ZStack {
            LocalAlbumThumbnail(fileURL: item.localFileURL)
            UploadPhotoOverlay(state: item.state)
        }
        .contentShape(Rectangle())
    }

    private var accessibilityLabel: String {
        switch item.state {
        case .uploading:
            "Photo uploading"
        case .verifying:
            "Photo upload verifying"
        case .processing:
            "Photo processing"
        case .failed:
            "Photo upload failed"
        }
    }
}

private struct UploadPhotoOverlay: View {
    let state: UploadQueueState?

    var body: some View {
        ZStack {
            Color.black.opacity(0.26)

            if state == .failed {
                Image(systemName: "arrow.clockwise")
                    .font(.system(.title3, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.72), in: Circle())
            } else {
                ProgressView()
                    .controlSize(.regular)
                    .tint(.white)
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.58), in: Circle())
            }

            VStack {
                Spacer()
                HStack {
                    PhotoStatusBadge(
                        title: label,
                        systemImage: icon
                    )
                    Spacer(minLength: 0)
                }
                .padding(6)
            }
        }
    }

    private var label: String {
        switch state {
        case nil:
            "Preparing"
        case .uploading:
            "Uploading"
        case .verifying:
            "Verifying"
        case .processing:
            "Processing"
        case .failed:
            "Tap to retry"
        }
    }

    private var icon: String {
        switch state {
        case nil:
            "photo"
        case .uploading:
            "arrow.up"
        case .verifying:
            "checkmark.shield"
        case .processing:
            "wand.and.stars"
        case .failed:
            "exclamationmark.circle"
        }
    }
}

private struct LocalAlbumThumbnail: View {
    let fileURL: URL
    @State private var image: UIImage?

    var body: some View {
        Rectangle()
            .fill(AppTheme.softFill)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    ProgressView()
                }
            }
            .clipped()
            .task(id: fileURL) {
                image = await Self.loadImage(at: fileURL)
            }
    }

    private static func loadImage(at fileURL: URL) async -> UIImage? {
        await LocalImageThumbnailer.make(fileURL: fileURL)
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
    let eventID: String
    let photo: AlbumPhoto
    let eventExpiresAt: Date?
    let onLoadFailure: () -> Void

    var body: some View {
        Rectangle()
            .fill(AppTheme.softFill)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                CachedEventImage(
                    eventID: eventID,
                    photo: photo,
                    variant: .thumbnail,
                    eventExpiresAt: eventExpiresAt,
                    contentMode: .fill,
                    onFailure: onLoadFailure
                ) {
                    if AlbumMediaURLRefreshPolicy.isUsable(
                        photo.urlsExpireAt
                    ) {
                        ProgressView()
                    } else {
                        Image(systemName: "photo")
                            .foregroundStyle(AppTheme.secondaryInk)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .clipped()
            .accessibilityLabel("Event photo")
    }
}
