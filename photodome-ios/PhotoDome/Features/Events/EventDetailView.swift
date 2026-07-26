import SwiftUI
import UIKit

struct EventDetailView: View {
    let eventID: String
    @ObservedObject var model: EventAppViewModel
    let initiallyPresentsCamera: Bool
    let cameraPresentationRequestID: UUID?

    @State private var showsRotationConfirmation = false
    @State private var showsEndConfirmation = false
    @State private var showsRestrictionConfirmation = false
    @State private var memberPendingRemoval: EventMember?
    @State private var transfer: HostTransfer?
    @State private var isWorking = false

    init(
        eventID: String,
        model: EventAppViewModel,
        initiallyPresentsCamera: Bool = false,
        cameraPresentationRequestID: UUID? = nil
    ) {
        self.eventID = eventID
        self.model = model
        self.initiallyPresentsCamera = initiallyPresentsCamera
        self.cameraPresentationRequestID = cameraPresentationRequestID
    }

    var body: some View {
        Group {
            if let access = model.access(eventID: eventID) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        summary(access)

                        if access.event.role == .host {
                            hostInvite(access)
                            attendeeControls(access)
                        }

                        if access.event.state == .ended
                            || (access.event.state == .live
                                && access.event.role == .host),
                            (access.event.readyPhotoCount ?? 0) > 0
                        {
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
                .confirmationDialog(
                    "Remove this attendee?",
                    isPresented: Binding(
                        get: { memberPendingRemoval != nil },
                        set: { if !$0 { memberPendingRemoval = nil } }
                    ),
                    titleVisibility: .visible
                ) {
                    Button("Remove attendee", role: .destructive) {
                        guard let member = memberPendingRemoval else { return }
                        memberPendingRemoval = nil
                        Task {
                            isWorking = true
                            _ = await model.removeMember(
                                eventID: eventID,
                                memberID: member.id
                            )
                            isWorking = false
                        }
                    }
                    Button("Cancel", role: .cancel) {
                        memberPendingRemoval = nil
                    }
                } message: {
                    Text(
                        "Their event access is revoked immediately on every open screen."
                    )
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
        .task {
            await model.refresh(eventID: eventID)
            await model.loadMembers(eventID: eventID)
        }
    }

    private func summary(_ access: StoredEventAccess) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(
                access.event.state == .live
                    ? "LIVE EVENT" : access.event.state.rawValue.uppercased()
            )
            .font(AppTheme.eyebrow)
            .foregroundStyle(AppTheme.secondaryInk)

            Text("Hosted by \(access.event.hostDisplayName ?? "Host")")
                .foregroundStyle(AppTheme.secondaryInk)

            VStack(alignment: .leading, spacing: 5) {
                if let started = EventTimestampFormatter.localDateTime(
                    access.event.createdAt
                ) {
                    Text("Started \(started)")
                }
                if access.event.state == .ended,
                    let ended = EventTimestampFormatter.localDateTime(
                        access.event.endedAt
                    )
                {
                    Text("Ended \(ended)")
                }
            }
            .font(.footnote)
            .foregroundStyle(AppTheme.secondaryInk)

            HStack(spacing: 18) {
                Label(
                    "\(access.event.memberCount) attending",
                    systemImage: "person.2"
                )
                Label(
                    access.event.role == .host ? "You’re host" : "You’re a guest",
                    systemImage: access.event.role == .host
                        ? "key" : "person"
                )
            }
            .font(.system(.footnote, design: .rounded, weight: .medium))
            .foregroundStyle(AppTheme.secondaryInk)

            if access.event.state == .ended {
                VStack(alignment: .leading, spacing: 5) {
                    Text(
                        access.event.uploadsRestrictedAt == nil
                            ? "Uploads remain open"
                            : "New uploads are restricted"
                    )
                    if let expiry = formattedDate(access.event.expiresAt) {
                        Text("Photos expire \(expiry)")
                    }
                }
                .font(.footnote)
                .foregroundStyle(AppTheme.secondaryInk)
            }
        }
    }

    private func hostInvite(_ access: StoredEventAccess) -> some View {
        VStack(alignment: .center, spacing: 16) {
            Text("INVITE PEOPLE")
                .font(AppTheme.eyebrow)
                .foregroundStyle(AppTheme.secondaryInk)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let joinCode = access.joinCode {
                let invite = InvitePayload.join(code: joinCode)

                QRCodeView(
                    url: invite.url,
                    size: 220,
                    accessibilityLabel: "Event invite QR code"
                )

                Text(joinCode)
                    .font(.system(.title, design: .monospaced, weight: .bold))
                    .tracking(3)
                    .accessibilityLabel(
                        "Join code \(joinCode.map(String.init).joined(separator: " "))"
                    )

                HStack {
                    Button("Copy code") {
                        UIPasteboard.general.string = joinCode
                    }
                    .buttonStyle(OutlineButtonStyle())

                    ShareLink(item: invite.url) {
                        Text("Share invite")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(OutlineButtonStyle())
                }
            } else {
                Text("Rotate the code to create a new invite.")
                    .foregroundStyle(AppTheme.secondaryInk)
            }
        }
        .padding(20)
        .background(AppTheme.softFill)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
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
            } else if access.event.state == .ended,
                access.event.uploadsRestrictedAt == nil
            {
                Button("Restrict new uploads") {
                    showsRestrictionConfirmation = true
                }
                .buttonStyle(OutlineButtonStyle())
                .disabled(isWorking)
            }

            Text(
                "Host transfer creates a one-time QR that expires shortly. Accepting it removes host control from this device."
            )
            .font(.footnote)
            .foregroundStyle(AppTheme.secondaryInk)
        }
    }

    private func attendeeControls(
        _ access: StoredEventAccess
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ATTENDEES")
                .font(AppTheme.eyebrow)
                .foregroundStyle(AppTheme.secondaryInk)

            let guests = (model.membersByEvent[access.id] ?? []).filter {
                $0.role == .guest
            }
            if guests.isEmpty {
                Text("No guests are currently in this event.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryInk)
            } else {
                ForEach(guests) { member in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(member.displayName)
                                .font(
                                    .system(
                                        .body,
                                        design: .rounded,
                                        weight: .semibold
                                    )
                                )
                            if let joined = formattedDate(member.joinedAt) {
                                Text("Joined \(joined)")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.secondaryInk)
                            }
                        }
                        Spacer()
                        Button("Remove", role: .destructive) {
                            memberPendingRemoval = member
                        }
                        .disabled(isWorking)
                    }
                    .padding(14)
                    .background(AppTheme.softFill)
                    .clipShape(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    )
                }
            }
        }
    }

    private func formattedDate(_ value: String?) -> String? {
        EventTimestampFormatter.localDateTime(value)
    }

}

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

                ShareLink(item: payload.url) {
                    Text("Share transfer link")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(OutlineButtonStyle())

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
