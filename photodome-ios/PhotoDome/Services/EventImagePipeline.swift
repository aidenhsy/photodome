import Foundation
import Kingfisher
import SwiftUI

enum EventImageVariant: String, CaseIterable, Sendable {
    case thumbnail
    case display

    var maximumPixelSize: CGFloat {
        switch self {
        case .thumbnail:
            512
        case .display:
            1_280
        }
    }

    var processor: DownsamplingImageProcessor {
        DownsamplingImageProcessor(
            size: CGSize(
                width: maximumPixelSize,
                height: maximumPixelSize
            )
        )
    }
}

enum EventImageCacheKey {
    static func make(
        eventID: String,
        photoID: String,
        variant: EventImageVariant
    ) -> String {
        "photodome-event-media-v1|\(eventID)|\(photoID)|\(variant.rawValue)"
    }
}

@MainActor
final class EventImagePipeline {
    static let shared = EventImagePipeline()

    let cache: ImageCache
    private var prefetchers: [UUID: ImagePrefetcher] = [:]

    init(cache: ImageCache? = nil) {
        self.cache = cache ?? Self.makeCache()
        self.cache.memoryStorage.config.totalCostLimit = 96 * 1_024 * 1_024
        self.cache.memoryStorage.config.countLimit = 180
        self.cache.memoryStorage.config.expiration = .seconds(600)
        self.cache.diskStorage.config.sizeLimit = 512 * 1_024 * 1_024
        self.cache.diskStorage.config.expiration = .days(7)
    }

    func resource(
        eventID: String,
        photoID: String,
        variant: EventImageVariant,
        url: URL
    ) -> KF.ImageResource {
        KF.ImageResource(
            downloadURL: url,
            cacheKey: EventImageCacheKey.make(
                eventID: eventID,
                photoID: photoID,
                variant: variant
            )
        )
    }

    func prefetch(
        eventID: String,
        photos: [AlbumPhoto],
        variant: EventImageVariant,
        eventExpiresAt: Date?
    ) {
        guard !photos.isEmpty else { return }
        let resources = photos.map {
            resource(
                eventID: eventID,
                photoID: $0.id,
                variant: variant,
                url: variant == .thumbnail
                    ? $0.thumbnailURL : $0.displayURL
            )
        }
        let id = UUID()
        let prefetcher = ImagePrefetcher(
            resources: resources,
            options: options(
                variant: variant,
                eventExpiresAt: eventExpiresAt
            )
        ) { [weak self] _, _, _ in
            Task { @MainActor [weak self] in
                self?.prefetchers[id] = nil
            }
        }
        prefetchers[id] = prefetcher
        prefetcher.start()
    }

    func removePhoto(eventID: String, photoID: String) async {
        for variant in EventImageVariant.allCases {
            await remove(
                key: EventImageCacheKey.make(
                    eventID: eventID,
                    photoID: photoID,
                    variant: variant
                ),
                processorIdentifier: variant.processor.identifier
            )
        }
    }

    func removeEvent(eventID: String, photoIDs: [String]) async {
        for photoID in photoIDs {
            await removePhoto(eventID: eventID, photoID: photoID)
        }
    }

    func clearAll() async {
        cache.clearMemoryCache()
        await cache.clearDiskCache()
    }

    func options(
        variant: EventImageVariant,
        eventExpiresAt: Date?
    ) -> KingfisherOptionsInfo {
        [
            .targetCache(cache),
            .processor(variant.processor),
            .scaleFactor(1),
            .memoryCacheExpiration(
                memoryExpiration(eventExpiresAt: eventExpiresAt)
            ),
            .diskCacheExpiration(
                eventExpiresAt.map(StorageExpiration.date) ?? .days(7)
            ),
        ]
    }

    func memoryExpiration(eventExpiresAt: Date?) -> StorageExpiration {
        let normalExpiration = Date().addingTimeInterval(600)
        guard
            let eventExpiresAt,
            eventExpiresAt < normalExpiration
        else {
            return .seconds(600)
        }
        return .date(eventExpiresAt)
    }

    private func remove(
        key: String,
        processorIdentifier: String
    ) async {
        await withCheckedContinuation { continuation in
            cache.removeImage(
                forKey: key,
                processorIdentifier: processorIdentifier
            ) {
                continuation.resume()
            }
        }
    }

    private static func makeCache() -> ImageCache {
        do {
            let baseURL = try FileManager.default.url(
                for: .cachesDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ).appendingPathComponent(
                "PhotoDomeEventMedia",
                isDirectory: true
            )
            try FileManager.default.createDirectory(
                at: baseURL,
                withIntermediateDirectories: true,
                attributes: [
                    .protectionKey:
                        FileProtectionType
                        .completeUntilFirstUserAuthentication
                ]
            )
            return try ImageCache(
                name: "photodome-event-media",
                cacheDirectoryURL: baseURL
            )
        } catch {
            return ImageCache(name: "photodome-event-media-fallback")
        }
    }
}

struct CachedEventImage<Placeholder: View>: View {
    let eventID: String
    let photo: AlbumPhoto
    let variant: EventImageVariant
    let eventExpiresAt: Date?
    let contentMode: SwiftUI.ContentMode
    let onFailure: () -> Void
    private let placeholder: Placeholder

    init(
        eventID: String,
        photo: AlbumPhoto,
        variant: EventImageVariant,
        eventExpiresAt: Date?,
        contentMode: SwiftUI.ContentMode,
        onFailure: @escaping () -> Void = {},
        @ViewBuilder placeholder: () -> Placeholder
    ) {
        self.eventID = eventID
        self.photo = photo
        self.variant = variant
        self.eventExpiresAt = eventExpiresAt
        self.contentMode = contentMode
        self.onFailure = onFailure
        self.placeholder = placeholder()
    }

    var body: some View {
        let pipeline = EventImagePipeline.shared
        let url =
            variant == .thumbnail
            ? photo.thumbnailURL : photo.displayURL
        let resource = pipeline.resource(
            eventID: eventID,
            photoID: photo.id,
            variant: variant,
            url: url
        )
        let permitsNetwork = AlbumMediaURLRefreshPolicy.isUsable(
            photo.urlsExpireAt
        )

        KFImage(source: .network(resource))
            .placeholder { placeholder }
            .onFailure { _ in onFailure() }
            .cancelOnDisappear(false)
            .targetCache(pipeline.cache)
            .setProcessor(variant.processor)
            .scaleFactor(1)
            .onlyFromCache(!permitsNetwork)
            .loadDiskFileSynchronously(variant == .thumbnail)
            .memoryCacheExpiration(
                pipeline.memoryExpiration(eventExpiresAt: eventExpiresAt)
            )
            .diskCacheExpiration(
                eventExpiresAt.map(StorageExpiration.date) ?? .days(7)
            )
            .fade(duration: 0.12)
            .resizable()
            .aspectRatio(contentMode: contentMode)
    }
}

@MainActor
enum EventMediaCache {
    static func removePhoto(eventID: String, photoID: String) async {
        await EventImagePipeline.shared.removePhoto(
            eventID: eventID,
            photoID: photoID
        )
    }

    static func removeEvent(eventID: String) async {
        do {
            let photoIDs = try await AlbumSnapshotStore.shared.remove(
                eventID: eventID
            )
            if photoIDs.isEmpty {
                await EventImagePipeline.shared.clearAll()
            } else {
                await EventImagePipeline.shared.removeEvent(
                    eventID: eventID,
                    photoIDs: photoIDs
                )
            }
        } catch {
            await EventImagePipeline.shared.clearAll()
        }
    }
}
