import Foundation
import OpenAPIRuntime
import OpenAPIURLSession

enum APIClientError: LocalizedError, Equatable {
    case invalidInvite
    case unauthorized
    case forbidden
    case eventUnavailable
    case eventFull
    case uploadsClosed
    case curationUnavailable
    case invalidMedia
    case unexpectedStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidInvite:
            "That invitation is no longer valid."
        case .unauthorized:
            "This device no longer has access to the event."
        case .forbidden:
            "Only the current host can do that."
        case .eventUnavailable:
            "The event is no longer available."
        case .eventFull:
            "This event has reached its 100-person limit."
        case .uploadsClosed:
            "This event is not accepting new photo uploads."
        case .curationUnavailable:
            "Photo take-home is available after the event ends and before it expires."
        case .invalidMedia:
            "That photo upload could not be verified."
        case .unexpectedStatus(let status):
            "The PhotoDome service returned status \(status)."
        }
    }
}

extension Error {
    var photoDomeMessage: String {
        if let apiError = self as? APIClientError {
            return apiError.localizedDescription
        }
        if containsNetworkFailure {
            return "PhotoDome can’t connect to the server. Try again shortly."
        }
        return "Something went wrong. Please try again."
    }

    private var containsNetworkFailure: Bool {
        func isNetworkFailure(_ error: NSError, depth: Int) -> Bool {
            guard depth < 6 else { return false }
            if error.domain == NSURLErrorDomain,
                error.code != NSURLErrorCancelled
            {
                return true
            }
            if let underlying = error.userInfo[NSUnderlyingErrorKey]
                as? NSError,
                isNetworkFailure(underlying, depth: depth + 1)
            {
                return true
            }
            let description = error.localizedDescription.lowercased()
            return description.contains("nsurlerrordomain")
                || description.contains("could not connect to the server")
                || description.contains("network connection was lost")
        }
        return isNetworkFailure(self as NSError, depth: 0)
    }
}

struct APIClient: Sendable {
    private let baseURL: URL
    private let installationIdentity: String
    private let generated: Client

    init(baseURL: URL, installationIdentity: String = "development-client") {
        self.baseURL = baseURL
        self.installationIdentity = installationIdentity
        generated = Client(
            serverURL: baseURL,
            transport: URLSessionTransport(),
            middlewares: [
                InstallationIdentityMiddleware(identity: installationIdentity)
            ]
        )
    }

    func checkHealth() async throws {
        switch try await generated.getHealth(.init()) {
        case .ok:
            return
        case .undocumented(let statusCode, _):
            throw mapStatus(statusCode)
        }
    }

    func createEvent(name: String, displayName: String) async throws
        -> StoredEventAccess
    {
        let output = try await generated.createEvent(
            .init(
                body: .json(
                    .init(name: name, displayName: displayName)
                )
            )
        )
        switch output {
        case .created(let response):
            let dto = try response.body.json
            return StoredEventAccess(
                event: map(dto.event),
                capability: dto.capability,
                joinCode: dto.joinCode
            )
        case .undocumented(let statusCode, _):
            throw mapStatus(statusCode)
        }
    }

    func joinEvent(code: String, displayName: String) async throws
        -> StoredEventAccess
    {
        let output = try await generated.joinEvent(
            .init(
                body: .json(
                    .init(joinCode: code, displayName: displayName)
                )
            )
        )
        switch output {
        case .ok(let response):
            let dto = try response.body.json
            return StoredEventAccess(
                event: map(dto.event),
                capability: dto.capability,
                joinCode: nil
            )
        case .notFound:
            throw APIClientError.invalidInvite
        case .undocumented(let statusCode, _):
            throw mapStatus(statusCode)
        }
    }

    func getEvent(eventID: String, capability: String) async throws
        -> EventSnapshot
    {
        let client = authorizedClient(capability: capability)
        let output = try await client.getEvent(
            .init(path: .init(eventId: eventID))
        )
        switch output {
        case .ok(let response):
            return map(try response.body.json)
        case .undocumented(let statusCode, _):
            throw mapStatus(statusCode)
        }
    }

    func rotateJoinCode(eventID: String, capability: String) async throws
        -> String
    {
        let client = authorizedClient(capability: capability)
        let output = try await client.rotateEventJoinCode(
            .init(path: .init(eventId: eventID))
        )
        switch output {
        case .ok(let response):
            return try response.body.json.joinCode
        case .undocumented(let statusCode, _):
            throw mapStatus(statusCode)
        }
    }

    func endEvent(eventID: String, capability: String) async throws
        -> EventSnapshot
    {
        let output = try await authorizedClient(capability: capability)
            .endEvent(.init(path: .init(eventId: eventID)))
        switch output {
        case .ok(let response):
            return map(try response.body.json)
        case .undocumented(let statusCode, _):
            throw mapStatus(statusCode)
        }
    }

    func restrictUploads(eventID: String, capability: String) async throws
        -> EventSnapshot
    {
        let output = try await authorizedClient(capability: capability)
            .restrictEventUploads(.init(path: .init(eventId: eventID)))
        switch output {
        case .ok(let response):
            return map(try response.body.json)
        case .undocumented(let statusCode, _):
            throw mapStatus(statusCode)
        }
    }

    func listMembers(eventID: String, capability: String) async throws
        -> [EventMember]
    {
        let output = try await authorizedClient(capability: capability)
            .listEventMembers(.init(path: .init(eventId: eventID)))
        switch output {
        case .ok(let response):
            return try response.body.json.map { member in
                EventMember(
                    id: member.id,
                    displayName: member.displayName,
                    role: member.role == .host ? .host : .guest,
                    joinedAt: member.joinedAt,
                    isViewer: member.isViewer
                )
            }
        case .undocumented(let statusCode, _):
            throw mapStatus(statusCode)
        }
    }

    func updateDisplayName(
        eventID: String,
        capability: String,
        displayName: String
    ) async throws -> EventSnapshot {
        let output = try await authorizedClient(capability: capability)
            .updateOwnEventDisplayName(
                .init(
                    path: .init(eventId: eventID),
                    body: .json(.init(displayName: displayName))
                )
            )
        switch output {
        case .ok(let response):
            return map(try response.body.json)
        case .undocumented(let statusCode, _):
            throw mapStatus(statusCode)
        }
    }

    func removeMember(
        eventID: String,
        memberID: String,
        capability: String
    ) async throws {
        let output = try await authorizedClient(capability: capability)
            .removeEventMember(
                .init(
                    path: .init(eventId: eventID, memberId: memberID)
                )
            )
        switch output {
        case .noContent:
            return
        case .undocumented(let statusCode, _):
            throw mapStatus(statusCode)
        }
    }

    func createHostTransfer(
        eventID: String,
        capability: String,
        joinCode: String?
    ) async throws -> HostTransfer {
        let client = authorizedClient(capability: capability)
        let output = try await client.createHostTransfer(
            .init(path: .init(eventId: eventID))
        )
        switch output {
        case .ok(let response):
            let dto = try response.body.json
            return HostTransfer(
                eventID: eventID,
                transferToken: dto.transferToken,
                joinCode: joinCode,
                expiresAt: dto.expiresAt
            )
        case .undocumented(let statusCode, _):
            throw mapStatus(statusCode)
        }
    }

    func exchangeHostTransfer(
        token: String,
        joinCode: String?
    ) async throws -> StoredEventAccess {
        let output = try await generated.exchangeHostTransfer(
            .init(body: .json(.init(transferToken: token)))
        )
        switch output {
        case .ok(let response):
            let dto = try response.body.json
            return StoredEventAccess(
                event: map(dto.event),
                capability: dto.capability,
                joinCode: joinCode
            )
        case .notFound:
            throw APIClientError.invalidInvite
        case .undocumented(let statusCode, _):
            throw mapStatus(statusCode)
        }
    }

    func reservePhoto(
        eventID: String,
        capability: String,
        prepared: PreparedPhoto
    ) async throws -> PhotoUploadGrant {
        let client = authorizedClient(capability: capability)
        let output = try await client.reservePhotoUpload(
            .init(
                path: .init(eventId: eventID),
                body: .json(
                    .init(
                        contentType: .imageJpeg,
                        byteSize: Double(prepared.byteSize),
                        sha256: prepared.sha256,
                        width: Double(prepared.width),
                        height: Double(prepared.height),
                        capturedAt: prepared.capturedAt,
                        orientation: Double(prepared.orientation)
                    )
                )
            )
        )
        switch output {
        case .created(let response):
            return try map(try response.body.json)
        case .conflict:
            throw APIClientError.uploadsClosed
        case .undocumented(let statusCode, _):
            throw mapStatus(statusCode)
        }
    }

    func renewPhotoUpload(
        eventID: String,
        photoID: String,
        capability: String
    ) async throws -> PhotoUploadGrant {
        let output = try await authorizedClient(capability: capability)
            .renewPhotoUploadSession(
                .init(
                    path: .init(eventId: eventID, photoId: photoID)
                )
            )
        switch output {
        case .ok(let response):
            return try map(try response.body.json)
        case .undocumented(let statusCode, _):
            throw mapStatus(statusCode)
        }
    }

    func completePhotoUpload(
        eventID: String,
        photoID: String,
        capability: String
    ) async throws {
        let output = try await authorizedClient(capability: capability)
            .completePhotoUpload(
                .init(
                    path: .init(eventId: eventID, photoId: photoID)
                )
            )
        switch output {
        case .ok:
            return
        case .undocumented(let statusCode, _):
            if statusCode == 422 {
                throw APIClientError.invalidMedia
            }
            throw mapStatus(statusCode)
        }
    }

    func listPhotos(
        eventID: String,
        capability: String,
        cursor: String? = nil
    ) async throws -> AlbumPhotoPage {
        let output = try await authorizedClient(capability: capability)
            .listEventPhotos(
                .init(
                    path: .init(eventId: eventID),
                    query: .init(cursor: cursor)
                )
            )
        switch output {
        case .ok(let response):
            let dto = try response.body.json
            let photos: [AlbumPhoto] = dto.photos.compactMap { photo in
                guard
                    let displayURL = URL(string: photo.displayUrl),
                    let thumbnailURL = URL(string: photo.thumbnailUrl)
                else {
                    return nil
                }
                return AlbumPhoto(
                    id: photo.id,
                    contributorMemberID: photo.contributorMemberId,
                    width: Int(photo.width),
                    height: Int(photo.height),
                    capturedAt: photo.capturedAt,
                    readyAt: photo.readyAt,
                    displayURL: displayURL,
                    thumbnailURL: thumbnailURL,
                    urlsExpireAt: photo.urlsExpireAt
                )
            }
            return AlbumPhotoPage(
                photos: photos,
                nextCursor: dto.nextCursor,
                readyPhotoCount: Int(dto.readyPhotoCount)
            )
        case .undocumented(let statusCode, _):
            throw mapStatus(statusCode)
        }
    }

    func removePhoto(
        eventID: String,
        photoID: String,
        capability: String
    ) async throws {
        let output = try await authorizedClient(capability: capability)
            .removeEventPhoto(
                .init(path: .init(eventId: eventID, photoId: photoID))
            )
        switch output {
        case .noContent:
            return
        case .undocumented(let statusCode, _):
            throw mapStatus(statusCode)
        }
    }

    func getReviewQueue(
        eventID: String,
        capability: String,
        cursor: String? = nil
    ) async throws -> ReviewPhotoPage {
        let output = try await authorizedClient(capability: capability)
            .getPhotoReviewQueue(
                .init(
                    path: .init(eventId: eventID),
                    query: .init(cursor: cursor)
                )
            )
        switch output {
        case .ok(let response):
            let dto = try response.body.json
            return ReviewPhotoPage(
                photos: try dto.photos.map(mapReviewPhoto),
                nextCursor: dto.nextCursor,
                readyPhotoCount: Int(dto.readyPhotoCount),
                decidedPhotoCount: Int(dto.decidedPhotoCount),
                keptPhotoCount: Int(dto.keptPhotoCount)
            )
        case .undocumented(let statusCode, _):
            throw mapStatus(statusCode, conflict: .curationUnavailable)
        }
    }

    func setPhotoSelection(
        eventID: String,
        photoID: String,
        capability: String,
        decision: PhotoSelectionDecision
    ) async throws -> PhotoSelection {
        let generatedDecision: Components.Schemas.SetPhotoSelectionDto.DecisionPayload =
            decision == .keep ? .keep : .skip
        let output = try await authorizedClient(capability: capability)
            .setPhotoSelection(
                .init(
                    path: .init(eventId: eventID, photoId: photoID),
                    body: .json(.init(decision: generatedDecision))
                )
            )
        switch output {
        case .ok(let response):
            return map(try response.body.json)
        case .undocumented(let statusCode, _):
            throw mapStatus(statusCode, conflict: .curationUnavailable)
        }
    }

    func undoLatestSelection(
        eventID: String,
        capability: String
    ) async throws -> PhotoSelection? {
        let output = try await authorizedClient(capability: capability)
            .undoLatestSelection(.init(path: .init(eventId: eventID)))
        switch output {
        case .ok(let response):
            guard let selection = try response.body.json.selection?.value1
            else {
                return nil
            }
            return map(selection)
        case .undocumented(let statusCode, _):
            throw mapStatus(statusCode, conflict: .curationUnavailable)
        }
    }

    func getDownloadManifest(
        eventID: String,
        capability: String,
        mode: DownloadManifestMode,
        cursor: String? = nil,
        photoID: String? = nil
    ) async throws -> DownloadManifestPage {
        let generatedMode: Operations.GetDownloadManifest.Input.Query.ModePayload =
            mode == .all ? .all : .kept
        let output = try await authorizedClient(capability: capability)
            .getDownloadManifest(
                .init(
                    path: .init(eventId: eventID),
                    query: .init(
                        mode: generatedMode,
                        photoId: photoID,
                        cursor: cursor
                    )
                )
            )
        switch output {
        case .ok(let response):
            let dto = try response.body.json
            return DownloadManifestPage(
                photos: try dto.photos.map { photo in
                    guard let url = URL(string: photo.originalUrl) else {
                        throw APIClientError.invalidMedia
                    }
                    return DownloadManifestPhoto(
                        id: photo.id,
                        contentType: photo.contentType,
                        byteSize: Int(photo.byteSize),
                        capturedAt: photo.capturedAt,
                        readyAt: photo.readyAt,
                        originalURL: url,
                        urlExpiresAt: photo.urlExpiresAt
                    )
                },
                nextCursor: dto.nextCursor,
                totalPhotoCount: Int(dto.totalPhotoCount)
            )
        case .undocumented(let statusCode, _):
            throw mapStatus(statusCode, conflict: .curationUnavailable)
        }
    }

    func registerLiveActivityToken(
        eventID: String,
        capability: String,
        pushToken: String
    ) async throws {
        let output = try await authorizedClient(capability: capability)
            .registerEventLiveActivityToken(
                .init(
                    path: .init(eventId: eventID),
                    body: .json(.init(pushToken: pushToken))
                )
            )
        switch output {
        case .noContent:
            return
        case .undocumented(let statusCode, _):
            throw mapStatus(statusCode)
        }
    }

    private func authorizedClient(capability: String) -> Client {
        Client(
            serverURL: baseURL,
            transport: URLSessionTransport(),
            middlewares: [
                InstallationIdentityMiddleware(identity: installationIdentity),
                CapabilityAuthMiddleware(capability: capability),
            ]
        )
    }

    private func mapStatus(
        _ status: Int,
        conflict: APIClientError = .eventFull
    ) -> APIClientError {
        switch status {
        case 401:
            .unauthorized
        case 403:
            .forbidden
        case 404, 410:
            .eventUnavailable
        case 409:
            conflict
        default:
            .unexpectedStatus(status)
        }
    }

    private func map(
        _ dto: Components.Schemas.EventSnapshotDto
    ) -> EventSnapshot {
        let state: EventLifecycle =
            switch dto.state {
            case .live: .live
            case .ended: .ended
            case .expiring: .expiring
            }
        let role: EventRole =
            switch dto.viewer.role {
            case .host: .host
            case .guest: .guest
            }

        return EventSnapshot(
            id: dto.id,
            name: dto.name,
            hostDisplayName: dto.hostDisplayName,
            locationLabel: dto.locationLabel,
            state: state,
            memberCount: Int(dto.memberCount),
            readyPhotoCount: Int(dto.readyPhotoCount),
            createdAt: dto.createdAt,
            endedAt: dto.endedAt,
            expiresAt: dto.expiresAt,
            uploadsRestrictedAt: dto.uploadsRestrictedAt,
            memberID: dto.viewer.memberId,
            role: role
        )
    }

    private func mapReviewPhoto(
        _ dto: Components.Schemas.ReviewPhotoDto
    ) throws -> AlbumPhoto {
        guard
            let displayURL = URL(string: dto.displayUrl),
            let thumbnailURL = URL(string: dto.thumbnailUrl)
        else {
            throw APIClientError.invalidMedia
        }
        return AlbumPhoto(
            id: dto.id,
            contributorMemberID: dto.contributorMemberId,
            width: Int(dto.width),
            height: Int(dto.height),
            capturedAt: dto.capturedAt,
            readyAt: dto.readyAt,
            displayURL: displayURL,
            thumbnailURL: thumbnailURL,
            urlsExpireAt: dto.urlsExpireAt
        )
    }

    private func map(
        _ dto: Components.Schemas.PhotoSelectionDto
    ) -> PhotoSelection {
        PhotoSelection(
            photoID: dto.photoId,
            decision: dto.decision == .keep ? .keep : .skip,
            decidedAt: dto.decidedAt
        )
    }

    private func map(
        _ dto: Components.Schemas.PhotoUploadGrantDto
    ) throws -> PhotoUploadGrant {
        guard let uploadURL = URL(string: dto.uploadUrl) else {
            throw APIClientError.invalidMedia
        }
        return PhotoUploadGrant(
            photoID: dto.photoId,
            uploadURL: uploadURL,
            contentType: dto.contentType.rawValue,
            byteSize: Int(dto.byteSize)
        )
    }
}
