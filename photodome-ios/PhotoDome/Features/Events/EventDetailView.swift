import SwiftUI
import UIKit

struct EventDetailView: View {
    let eventID: String
    @ObservedObject var model: EventAppViewModel
    let initiallyPresentsCamera: Bool
    let cameraPresentationRequestID: UUID?
    let onInitialInvitePresented: () -> Void

    @State private var showsRotationConfirmation = false
    @State private var showsEndConfirmation = false
    @State private var showsRestrictionConfirmation = false
    @State private var showsAttendees = false
    @State private var showsInvite: Bool
    @State private var transfer: HostTransfer?
    @State private var isWorking = false

    init(
        eventID: String,
        model: EventAppViewModel,
        initiallyPresentsCamera: Bool = false,
        cameraPresentationRequestID: UUID? = nil,
        initiallyPresentsInvite: Bool = false,
        onInitialInvitePresented: @escaping () -> Void = {}
    ) {
        self.eventID = eventID
        self.model = model
        self.initiallyPresentsCamera = initiallyPresentsCamera
        self.cameraPresentationRequestID = cameraPresentationRequestID
        self.onInitialInvitePresented = onInitialInvitePresented
        _showsInvite = State(initialValue: initiallyPresentsInvite)
    }

    var body: some View {
        Group {
            if let access = model.access(eventID: eventID) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        summary(access)

                        if EventTakeHomePolicy.isAvailable(
                            for: access.event
                        ) {
                            EventTakeHomeView(access: access)
                        }

                        EventAlbumView(
                            access: access,
                            initiallyPresentsCamera:
                                initiallyPresentsCamera,
                            cameraPresentationRequestID:
                                cameraPresentationRequestID
                        ) { signal in
                            Task {
                                await model.handleRealtime(
                                    signal,
                                    eventID: eventID
                                )
                            }
                        }

                        if access.event.role == .host {
                            hostControls(access)
                        }
                    }
                    .padding(AppTheme.pagePadding)
                }
                .refreshable { await model.refresh(eventID: eventID) }
                .navigationTitle(access.event.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if access.event.role == .host {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                showsInvite = true
                            } label: {
                                Image(systemName: "person.badge.plus")
                            }
                            .accessibilityLabel("Invite people")
                            .accessibilityIdentifier("inviteButton")
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    "Event unavailable",
                    systemImage: "photo.stack"
                )
            }
        }
        .sheet(item: $transfer) { transfer in
            HostTransferView(transfer: transfer)
        }
        .sheet(isPresented: $showsInvite) {
            if let access = model.access(eventID: eventID) {
                EventInviteView(access: access)
            }
        }
        .sheet(isPresented: $showsAttendees) {
            if let access = model.access(eventID: eventID),
                AttendeeManagementPolicy.canOpenList(
                    viewerRole: access.event.role
                )
            {
                AttendeeListView(access: access, model: model)
            }
        }
        .task {
            if showsInvite {
                onInitialInvitePresented()
            }
            await model.refresh(eventID: eventID)
            await model.loadMembers(eventID: eventID)
        }
    }

    private func summary(_ access: StoredEventAccess) -> some View {
        VStack(alignment: .leading, spacing: PhotoDomeTokens.Space.x2) {
            HStack {
                PhotoDomeLifecyclePill(
                    title: lifecycleTitle(for: access.event.state),
                    tone: lifecycleTone(for: access.event.state)
                )

                Spacer()

                attendingControl(access)
            }
            .font(.system(.footnote, design: .rounded, weight: .medium))
            .foregroundStyle(AppTheme.secondaryInk)

            if access.event.role == .guest {
                Text(
                    "Hosted by \(access.event.hostDisplayName ?? "Host")"
                )
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(AppTheme.secondaryInk)
            }

            if access.event.state == .ended {
                HStack {
                    Label(
                        access.event.uploadsRestrictedAt == nil
                            ? "Uploads open"
                            : "Uploads closed",
                        systemImage: access.event.uploadsRestrictedAt == nil
                            ? "arrow.up.circle"
                            : "nosign"
                    )

                    Spacer()

                    if let countdown =
                        EventTimestampFormatter.deletionCountdown(
                            access.event.expiresAt
                        )
                    {
                        Text(countdown)
                    }
                }
                .font(.footnote)
                .foregroundStyle(AppTheme.secondaryInk)
            }
        }
    }

    private func lifecycleTitle(for lifecycle: EventLifecycle) -> String {
        switch lifecycle {
        case .live: "Live"
        case .ended: "Ended"
        case .expiring: "Expiring"
        }
    }

    private func lifecycleTone(
        for lifecycle: EventLifecycle
    ) -> PhotoDomeLifecycleTone {
        switch lifecycle {
        case .live: .live
        case .ended: .neutral
        case .expiring: .danger
        }
    }

    @ViewBuilder
    private func attendingControl(_ access: StoredEventAccess) -> some View {
        AttendeeCountControl(
            memberCount: access.event.memberCount,
            canOpen: AttendeeManagementPolicy.canOpenList(
                viewerRole: access.event.role
            )
        ) {
            showsAttendees = true
        }
    }

    private func hostControls(_ access: StoredEventAccess) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HOST CONTROLS")
                .font(AppTheme.eyebrow)
                .foregroundStyle(AppTheme.secondaryInk)

            Button("Rotate join code") {
                showsRotationConfirmation = true
            }
            .buttonStyle(OutlineButtonStyle())
            .disabled(isWorking)
            .confirmationDialog(
                "Rotate the join code?",
                isPresented: $showsRotationConfirmation,
                titleVisibility: .visible
            ) {
                Button("Rotate code", role: .destructive) {
                    Task {
                        isWorking = true
                        _ = await model.rotateJoinCode(eventID: eventID)
                        isWorking = false
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(
                    "Old QR codes and codes will stop working. People already in the event keep access."
                )
            }

            Button("Transfer host role") {
                Task {
                    isWorking = true
                    transfer = await model.createHostTransfer(eventID: access.id)
                    isWorking = false
                }
            }
            .buttonStyle(OutlineButtonStyle())
            .disabled(isWorking)

            if access.event.state == .live {
                Button("End event") {
                    showsEndConfirmation = true
                }
                .buttonStyle(DestructiveButtonStyle())
                .disabled(isWorking)
                .confirmationDialog(
                    "End this event?",
                    isPresented: $showsEndConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("End event", role: .destructive) {
                        Task {
                            isWorking = true
                            _ = await model.endEvent(eventID: eventID)
                            isWorking = false
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text(
                        "The live session ends now. Photos remain available for seven days, and uploads stay open unless you restrict them."
                    )
                }
            } else if access.event.state == .ended,
                access.event.uploadsRestrictedAt == nil
            {
                Button("Restrict new uploads") {
                    showsRestrictionConfirmation = true
                }
                .buttonStyle(OutlineButtonStyle())
                .disabled(isWorking)
                .confirmationDialog(
                    "Restrict new uploads?",
                    isPresented: $showsRestrictionConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Restrict uploads", role: .destructive) {
                        Task {
                            isWorking = true
                            _ = await model.restrictUploads(eventID: eventID)
                            isWorking = false
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text(
                        "New photos can’t be started. Uploads that were already admitted can still finish or retry."
                    )
                }
            }

        }
    }

}

private struct EventInviteView: View {
    let access: StoredEventAccess
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: PhotoDomeTokens.Space.x4) {
                if let joinCode = access.joinCode {
                    let invite = InvitePayload.join(code: joinCode)

                    QRCodeView(
                        url: invite.url,
                        size: 240,
                        accessibilityLabel: "Event invite QR code"
                    )

                    Text(joinCode)
                        .font(
                            .system(
                                .title,
                                design: .monospaced,
                                weight: .bold
                            )
                        )
                        .tracking(3)
                        .accessibilityLabel(
                            "Join code \(joinCode.map(String.init).joined(separator: " "))"
                        )

                    InviteCodeCopyButton(joinCode: joinCode)
                } else {
                    ContentUnavailableView(
                        "Invite unavailable",
                        systemImage: "qrcode",
                        description: Text(
                            "Create a new code from Host controls."
                        )
                    )
                }

                Spacer()
            }
            .padding(AppTheme.pagePadding)
            .navigationTitle("Invite people")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
}

private struct AttendeeListView: View {
    let access: StoredEventAccess
    @ObservedObject var model: EventAppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isWorking = false

    private var members: [EventMember]? {
        model.membersByEvent[access.id]
    }

    var body: some View {
        NavigationStack {
            Group {
                if let members {
                    AttendeeListContent(
                        members: members,
                        viewerRole: access.event.role,
                        isWorking: isWorking
                    ) { member in
                        Task {
                            isWorking = true
                            _ = await model.removeMember(
                                eventID: access.id,
                                memberID: member.id
                            )
                            isWorking = false
                        }
                    }
                    .refreshable {
                        await model.loadMembers(eventID: access.id)
                    }
                } else {
                    ProgressView("Loading attendees…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Attendees")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await model.loadMembers(eventID: access.id)
            }
        }
    }
}

struct InviteCodeCopyButton: View {
    let joinCode: String

    @State private var confirmationID: UUID?

    private var showsConfirmation: Bool {
        confirmationID != nil
    }

    var body: some View {
        Button {
            UIPasteboard.general.string = joinCode
            UIAccessibility.post(
                notification: .announcement,
                argument: "Code copied"
            )
            withAnimation(.easeInOut(duration: 0.15)) {
                confirmationID = UUID()
            }
        } label: {
            Label(
                showsConfirmation ? "Code copied" : "Copy code",
                systemImage: showsConfirmation
                    ? "checkmark.circle.fill"
                    : "doc.on.doc"
            )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(OutlineButtonStyle())
        .accessibilityIdentifier("copyJoinCodeButton")
        .task(id: confirmationID) {
            guard confirmationID != nil else {
                return
            }
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else {
                return
            }
            withAnimation(.easeInOut(duration: 0.15)) {
                confirmationID = nil
            }
        }
    }
}

struct AttendeeCountControl: View {
    let memberCount: Int
    let canOpen: Bool
    let open: () -> Void

    @ViewBuilder
    var body: some View {
        let label = Label(
            "\(memberCount) attending",
            systemImage: "person.2"
        )

        if canOpen {
            Button(action: open) {
                label
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the attendee list.")
            .accessibilityIdentifier("attendeeCountButton")
        } else {
            label
        }
    }
}

private struct AttendeeListContent: View {
    let members: [EventMember]
    let viewerRole: EventRole
    let isWorking: Bool
    let remove: (EventMember) -> Void
    @State private var memberPendingRemoval: EventMember?

    var body: some View {
        List(members) { member in
            attendeeRow(member)
        }
        .listStyle(.plain)
    }

    private func attendeeRow(_ member: EventMember) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .font(.title2)
                .foregroundStyle(AppTheme.secondaryInk)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(member.displayName)
                        .font(
                            .system(
                                .body,
                                design: .rounded,
                                weight: .semibold
                            )
                        )
                    if member.isViewer {
                        Text("You")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(AppTheme.secondaryInk)
                    }
                    if member.role == .host {
                        Text("Host")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(AppTheme.secondaryInk)
                    }
                }

                if let joined = EventTimestampFormatter.localDateTime(
                    member.joinedAt
                ) {
                    Text("Joined \(joined)")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryInk)
                }
            }

            Spacer(minLength: 8)

            if AttendeeManagementPolicy.canRemove(
                member,
                viewerRole: viewerRole
            ) {
                Button("Remove", role: .destructive) {
                    memberPendingRemoval = member
                }
                .disabled(isWorking)
                .accessibilityIdentifier("removeAttendee.\(member.id)")
                .confirmationDialog(
                    "Remove \(member.displayName)?",
                    isPresented: removalBinding(for: member),
                    titleVisibility: .visible
                ) {
                    Button("Remove attendee", role: .destructive) {
                        memberPendingRemoval = nil
                        remove(member)
                    }
                    Button("Cancel", role: .cancel) {
                        memberPendingRemoval = nil
                    }
                } message: {
                    Text(
                        "Their event access is revoked immediately on every open screen."
                    )
                }
            }
        }
    }

    private func removalBinding(for member: EventMember) -> Binding<Bool> {
        Binding(
            get: { memberPendingRemoval?.id == member.id },
            set: { isPresented in
                if !isPresented, memberPendingRemoval?.id == member.id {
                    memberPendingRemoval = nil
                }
            }
        )
    }
}

#if DEBUG
    struct InviteCodeCopyRegressionView: View {
        var body: some View {
            InviteCodeCopyButton(joinCode: "ABCD2345")
                .padding(AppTheme.pagePadding)
        }
    }

    struct HostTransferRegressionView: View {
        var body: some View {
            HostTransferView(
                transfer: HostTransfer(
                    eventID: "transfer-regression",
                    transferToken: "transfer-regression-token",
                    joinCode: "ABCD2345",
                    expiresAt: "2026-07-28T00:10:00.000Z"
                )
            )
        }
    }

    struct AttendeeListRegressionView: View {
        @State private var showsAttendees = false

        private let members =
            [
                EventMember(
                    id: "host",
                    displayName: "Host Person",
                    role: .host,
                    joinedAt: "2026-07-28T00:00:00.000Z",
                    isViewer: true
                )
            ]
            + (1...8).map { index in
                EventMember(
                    id: "guest-\(index)",
                    displayName: "Guest Person \(index)",
                    role: .guest,
                    joinedAt: "2026-07-28T00:0\(index):00.000Z",
                    isViewer: false
                )
            }

        var body: some View {
            AttendeeCountControl(
                memberCount: members.count,
                canOpen: true
            ) {
                showsAttendees = true
            }
            .sheet(isPresented: $showsAttendees) {
                NavigationStack {
                    AttendeeListContent(
                        members: members,
                        viewerRole: .host,
                        isWorking: false
                    ) { _ in }
                    .navigationTitle("Attendees")
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
    }
#endif

private struct HostTransferView: View {
    let transfer: HostTransfer
    @Environment(\.dismiss) private var dismiss

    private var payload: InvitePayload {
        .hostTransfer(
            token: transfer.transferToken,
            eventID: transfer.eventID,
            joinCode: transfer.joinCode
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Text("Scan on the new host’s iPhone")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .multilineTextAlignment(.center)

                QRCodeView(
                    url: payload.url,
                    size: 260,
                    accessibilityLabel: "One-time host transfer QR code"
                )

                Text("ONE-TIME • SHORT-LIVED")
                    .font(AppTheme.eyebrow)
                    .foregroundStyle(AppTheme.secondaryInk)

                Text(
                    "When accepted, this device immediately loses host authority. Never post this QR publicly."
                )
                .font(.system(.body, design: .rounded))
                .foregroundStyle(AppTheme.secondaryInk)
                .multilineTextAlignment(.center)

                Spacer()
            }
            .padding(AppTheme.pagePadding)
            .navigationTitle("Transfer host")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

extension HostTransfer: Identifiable {
    var id: String { transferToken }
}
