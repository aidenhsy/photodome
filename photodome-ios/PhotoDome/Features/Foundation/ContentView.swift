import SwiftUI

struct ContentView: View {
    @StateObject private var model = EventAppViewModel()
    @StateObject private var permissions = PermissionCenter()
    @StateObject private var profile = DeviceProfile()
    @State private var showsCreate = false
    @State private var showsJoin = false
    @State private var showsSettings = false
    @State private var showsMenu = false
    @State private var showsArchives = false
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
            .navigationTitle("Your Events")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HomeMenuButton {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            showsMenu = true
                        }
                    }
                }

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
            .navigationDestination(isPresented: $showsArchives) {
                ArchivedEventsView(model: model)
            }
        }
        .overlay {
            HomeNavigationMenu(
                isPresented: $showsMenu,
                archivedCount: model.archivedEvents.count
            ) {
                withAnimation(.easeInOut(duration: 0.22)) {
                    showsMenu = false
                }
                Task { @MainActor in
                    await Task.yield()
                    showsArchives = true
                }
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
        Group {
            if model.activeEvents.isEmpty {
                ScrollView {
                    emptyState
                }
                .background(AppTheme.canvas)
            } else {
                List {
                    ForEach(model.activeEvents) { access in
                        EventListRow(
                            access: access,
                            isArchived: false
                        ) {
                            model.archive(eventID: access.id)
                        }
                        .eventListRowStyle()
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(AppTheme.canvas)
            }
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

    @ViewBuilder
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: PhotoDomeTokens.Space.x2) {
            Text(
                model.archivedEvents.isEmpty
                    ? "No events yet."
                    : "No events in Your Events."
            )
            if !model.archivedEvents.isEmpty {
                Text("Open Archives from the menu to find archived events.")
                    .font(.footnote)
            }
        }
        .font(.system(.body, design: .rounded))
        .foregroundStyle(AppTheme.ink)
        .padding(.horizontal, AppTheme.pagePadding)
        .padding(.vertical, PhotoDomeTokens.Space.x4)
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

private struct ArchivedEventsView: View {
    @ObservedObject var model: EventAppViewModel

    var body: some View {
        Group {
            if model.archivedEvents.isEmpty {
                ScrollView {
                    Text("No archived events.")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(AppTheme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(AppTheme.pagePadding)
                }
                .background(AppTheme.canvas)
            } else {
                List {
                    ForEach(model.archivedEvents) { access in
                        EventListRow(
                            access: access,
                            isArchived: true
                        ) {
                            model.unarchive(eventID: access.id)
                        }
                        .eventListRowStyle()
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(AppTheme.canvas)
            }
        }
        .navigationTitle("Archives")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct HomeMenuButton: View {
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            Image(systemName: "line.3.horizontal")
        }
        .accessibilityLabel("Menu")
        .accessibilityIdentifier("menuButton")
    }
}

private struct HomeNavigationMenu: View {
    @Binding var isPresented: Bool
    let archivedCount: Int
    let openArchives: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                if isPresented {
                    Color.black.opacity(0.28)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                isPresented = false
                            }
                        }
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 0) {
                        Text("PhotoDome")
                            .font(
                                .system(
                                    .title2,
                                    design: .rounded,
                                    weight: .bold
                                )
                            )
                            .padding(.bottom, PhotoDomeTokens.Space.x6)

                        Button(action: openArchives) {
                            HStack(spacing: PhotoDomeTokens.Space.x3) {
                                Image(systemName: "archivebox")
                                Text("Archives")
                                Spacer()
                                if archivedCount > 0 {
                                    Text("\(archivedCount)")
                                        .foregroundStyle(
                                            AppTheme.secondaryInk
                                        )
                                }
                            }
                            .font(PhotoDomeTokens.TypeStyle.headline)
                            .frame(
                                minHeight:
                                    PhotoDomeTokens.Size.minimumTouchTarget
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("archivesMenuButton")

                        Spacer()
                    }
                    .padding(.horizontal, AppTheme.pagePadding)
                    .padding(.top, proxy.safeAreaInsets.top + 24)
                    .padding(.bottom, proxy.safeAreaInsets.bottom + 24)
                    .frame(width: min(proxy.size.width * 0.82, 320))
                    .frame(maxHeight: .infinity, alignment: .topLeading)
                    .background(AppTheme.canvas)
                    .shadow(color: .black.opacity(0.16), radius: 24, x: 8)
                    .transition(.move(edge: .leading))
                }
            }
            .animation(.easeInOut(duration: 0.22), value: isPresented)
        }
        .allowsHitTesting(isPresented)
    }
}

private struct EventListRow: View {
    let access: StoredEventAccess
    let isArchived: Bool
    let toggleArchive: () -> Void

    private var actionTitle: String {
        isArchived ? "Unarchive" : "Archive"
    }

    private var actionSystemImage: String {
        isArchived ? "arrow.uturn.backward" : "archivebox"
    }

    var body: some View {
        NavigationLink(
            value: EventDeepLink.event(eventID: access.id)
        ) {
            EventCard(access: access)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("eventCard.\(access.id)")
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            archiveButton
                .tint(AppTheme.ink)
        }
        .contextMenu {
            archiveButton
        }
    }

    private var archiveButton: some View {
        Button(action: toggleArchive) {
            Label(actionTitle, systemImage: actionSystemImage)
        }
    }
}

extension View {
    fileprivate func eventListRowStyle() -> some View {
        listRowInsets(
            EdgeInsets(
                top: PhotoDomeTokens.Space.x2,
                leading: AppTheme.pagePadding,
                bottom: PhotoDomeTokens.Space.x2,
                trailing: AppTheme.pagePadding
            )
        )
        .listRowSeparator(.hidden)
        .listRowBackground(AppTheme.canvas)
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

#if DEBUG
    struct EventArchiveRegressionView: View {
        @State private var isArchived = false
        @State private var showsMenu = false
        @State private var showsArchives = false

        var body: some View {
            NavigationStack {
                List {
                    if !isArchived {
                        EventListRow(
                            access: Self.access,
                            isArchived: false
                        ) {
                            isArchived = true
                        }
                        .eventListRowStyle()
                    }
                }
                .listStyle(.plain)
                .navigationTitle("Your Events")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        HomeMenuButton {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                showsMenu = true
                            }
                        }
                    }
                }
                .navigationDestination(for: EventDeepLink.self) { _ in
                    Text("Event detail")
                }
                .navigationDestination(isPresented: $showsArchives) {
                    List {
                        if isArchived {
                            EventListRow(
                                access: Self.access,
                                isArchived: true
                            ) {
                                isArchived = false
                            }
                            .eventListRowStyle()
                        } else {
                            Text("No archived events.")
                        }
                    }
                    .listStyle(.plain)
                    .navigationTitle("Archives")
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
            .overlay {
                HomeNavigationMenu(
                    isPresented: $showsMenu,
                    archivedCount: isArchived ? 1 : 0
                ) {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        showsMenu = false
                    }
                    Task { @MainActor in
                        await Task.yield()
                        showsArchives = true
                    }
                }
            }
        }

        private static let access = StoredEventAccess(
            event: EventSnapshot(
                id: "archive-regression",
                name: "Archive Test Event",
                hostDisplayName: "Taylor",
                locationLabel: nil,
                state: .ended,
                memberCount: 2,
                readyPhotoCount: 3,
                createdAt: "2026-07-20T16:00:00.000Z",
                endedAt: "2026-07-20T18:00:00.000Z",
                expiresAt: "2026-07-27T18:00:00.000Z",
                uploadsRestrictedAt: nil,
                memberID: "archive-regression-member",
                role: .host
            ),
            capability: "pdc_archive_regression",
            joinCode: "ARCH2345"
        )
    }
#endif

#Preview {
    ContentView()
}
