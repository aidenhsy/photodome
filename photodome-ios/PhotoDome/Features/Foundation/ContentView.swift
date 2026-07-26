import SwiftUI

struct ContentView: View {
    @StateObject private var model = EventAppViewModel()
    @StateObject private var permissions = PermissionCenter()
    @StateObject private var profile = DeviceProfile()
    @State private var showsCreate = false
    @State private var showsJoin = false
    @State private var showsSettings = false
    @State private var pendingPermissionAction: PendingPermissionAction?
    @State private var pendingNameAction: PendingPermissionAction?
    @State private var hasDismissedInitialNamePrompt = false
    @State private var createdEventIDToOpen: String?
    @State private var path: [EventDeepLink] = []
    @State private var cameraPresentationRequestID: UUID?

    var body: some View {
        Group {
            if profile.isLoading {
                ZStack {
                    AppTheme.canvas.ignoresSafeArea()
                    ProgressView()
                        .tint(AppTheme.ink)
                }
                .task { await profile.load() }
            } else if profile.displayName == nil
                && !hasDismissedInitialNamePrompt
            {
                DisplayNameOnboardingView(profile: profile) {
                    pendingNameAction = nil
                    hasDismissedInitialNamePrompt = true
                }
            } else {
                mainContent
            }
        }
        .onChange(of: profile.displayName) {
            guard
                profile.displayName != nil,
                let action = pendingNameAction
            else {
                return
            }
            pendingNameAction = nil
            Task { @MainActor in
                await Task.yield()
                requirePermissions(for: action)
            }
        }
    }

    private var mainContent: some View {
        NavigationStack(path: $path) {
            ZStack {
                AppTheme.canvas.ignoresSafeArea()

                if model.isLoading {
                    ProgressView("Restoring your events…")
                        .tint(AppTheme.ink)
                } else {
                    eventList
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        pendingPermissionAction = nil
                        permissions.refresh()
                        showsSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                    .accessibilityIdentifier("settingsButton")
                }
            }
            .navigationDestination(for: EventDeepLink.self) { route in
                EventDetailView(
                    eventID: route.eventID,
                    model: model,
                    initiallyPresentsCamera: route.opensCamera,
                    cameraPresentationRequestID: route.opensCamera
                        ? cameraPresentationRequestID : nil
                )
            }
        }
        .task { await model.bootstrap() }
        .sheet(
            isPresented: $showsCreate,
            onDismiss: openCreatedEvent
        ) {
            CreateEventView { name in
                guard
                    let eventID = await model.create(
                        name: name,
                        displayName: profile.displayName ?? ""
                    )
                else {
                    return false
                }
                createdEventIDToOpen = eventID
                return true
            }
        }
        .sheet(isPresented: $showsJoin) {
            JoinEventView(
                joinCode: { code in
                    await model.join(
                        code: code,
                        displayName: profile.displayName ?? ""
                    )
                },
                handlePayload: { payload in
                    await model.handle(
                        payload,
                        displayName: profile.displayName ?? ""
                    )
                }
            )
        }
        .sheet(
            isPresented: $showsSettings,
            onDismiss: continuePendingPermissionAction
        ) {
            SettingsView(
                permissions: permissions,
                profile: profile,
                requiresPermissionSetup: pendingPermissionAction != nil,
                onSaveDisplayName: { displayName in
                    guard await profile.save(displayName) else {
                        return false
                    }
                    await model.updateDisplayName(displayName)
                    return true
                }
            )
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
        .onOpenURL { url in
            Task {
                await model.bootstrap()
                if let payload = InvitePayload(url: url) {
                    requireName(for: .invite(payload))
                    return
                }
                guard let route = EventDeepLink(url: url) else { return }
                guard model.access(eventID: route.eventID) != nil else {
                    model.presentedError =
                        "This iPhone does not have access to that event."
                    return
                }
                if route.opensCamera {
                    cameraPresentationRequestID = UUID()
                }
                path = [route]
            }
        }
    }

    private var eventList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                Text("YOUR EVENTS")
                    .font(AppTheme.eyebrow)
                    .foregroundStyle(AppTheme.secondaryInk)
                    .padding(.top, PhotoDomeTokens.Space.x2)

                if model.events.isEmpty {
                    emptyState
                } else {
                    ForEach(model.events) { access in
                        NavigationLink(
                            value: EventDeepLink.event(
                                eventID: access.id
                            )
                        ) {
                            EventCard(access: access)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(AppTheme.pagePadding)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: PhotoDomeTokens.Space.x2) {
                Button("Create an event") {
                    requireName(for: .create)
                }
                .buttonStyle(MonochromeButtonStyle())

                Button("Join an event") {
                    requireName(for: .join)
                }
                .buttonStyle(OutlineButtonStyle())
            }
            .padding(.horizontal, AppTheme.pagePadding)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
    }

    private var emptyState: some View {
        Text("No events yet.")
            .font(.system(.body, design: .rounded))
            .foregroundStyle(AppTheme.secondaryInk)
    }

    private func requirePermissions(for action: PendingPermissionAction) {
        permissions.refresh()
        guard permissions.isReadyForSession else {
            pendingPermissionAction = action
            showsSettings = true
            return
        }
        perform(action)
    }

    private func requireName(for action: PendingPermissionAction) {
        guard profile.displayName != nil else {
            pendingNameAction = action
            hasDismissedInitialNamePrompt = false
            return
        }
        requirePermissions(for: action)
    }

    private func openCreatedEvent() {
        guard let eventID = createdEventIDToOpen else { return }
        createdEventIDToOpen = nil
        Task { @MainActor in
            await Task.yield()
            path = [.event(eventID: eventID)]
        }
    }

    private func continuePendingPermissionAction() {
        permissions.refresh()
        guard let action = pendingPermissionAction else { return }
        pendingPermissionAction = nil
        guard permissions.isReadyForSession else { return }
        Task { @MainActor in
            await Task.yield()
            perform(action)
        }
    }

    private func perform(_ action: PendingPermissionAction) {
        switch action {
        case .create:
            showsCreate = true
        case .join:
            showsJoin = true
        case .invite(let payload):
            Task {
                _ = await model.handle(
                    payload,
                    displayName: profile.displayName ?? ""
                )
            }
        }
    }
}

private enum PendingPermissionAction {
    case create
    case join
    case invite(InvitePayload)
}

private struct EventCard: View {
    let access: StoredEventAccess

    private var isEnded: Bool {
        access.event.state == .ended
    }

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: PhotoDomeTokens.Space.x2) {
                    Text(access.event.name)
                        .font(
                            .system(
                                .title3,
                                design: .rounded,
                                weight: .semibold
                            )
                        )
                        .foregroundStyle(
                            isEnded ? AppTheme.secondaryInk : AppTheme.ink
                        )

                    if isEnded {
                        Text("ENDED")
                            .font(AppTheme.eyebrow)
                            .foregroundStyle(AppTheme.secondaryInk)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                AppTheme.hairline.opacity(0.55),
                                in: Capsule()
                            )
                    }
                }

                HStack(spacing: 10) {
                    Label(
                        "\(access.event.memberCount)",
                        systemImage: "person.2"
                    )
                    Text(access.event.role == .host ? "HOST" : "GUEST")
                }
                .font(AppTheme.eyebrow)
                .foregroundStyle(AppTheme.secondaryInk)

                Text(
                    "Hosted by \(access.event.hostDisplayName ?? "Host")"
                )
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(AppTheme.secondaryInk)

                VStack(alignment: .leading, spacing: 3) {
                    if let started = EventTimestampFormatter.localDateTime(
                        access.event.createdAt
                    ) {
                        Text("Started \(started)")
                    }
                    if isEnded,
                        let ended = EventTimestampFormatter.localDateTime(
                            access.event.endedAt
                        )
                    {
                        Text("Ended \(ended)")
                    }
                }
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(AppTheme.secondaryInk)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryInk)
        }
        .padding(18)
        .background(
            isEnded ? AppTheme.softFill.opacity(0.48) : AppTheme.softFill
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        .overlay {
            if isEnded {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .stroke(AppTheme.hairline)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ContentView()
}
