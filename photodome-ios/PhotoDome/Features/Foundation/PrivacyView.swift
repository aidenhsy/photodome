import SwiftUI

struct SettingsView: View {
    @ObservedObject var permissions: PermissionCenter
    @ObservedObject var profile: DeviceProfile
    let requiresPermissionSetup: Bool
    let onSaveDisplayName: (String) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var showsPrivacy = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        EditDisplayNameView(
                            displayName: profile.displayName ?? "",
                            onSave: onSaveDisplayName
                        )
                    } label: {
                        LabeledContent(
                            "Your name",
                            value: profile.displayName ?? "Not set"
                        )
                    }
                }

                if requiresPermissionSetup {
                    Section {
                        Text(
                            "Set up Camera, Photos, and Precise Location once before creating or joining an event. You can change these permissions here later."
                        )
                    }
                }

                Section {
                    PermissionSettingsRow(
                        icon: "camera",
                        title: "Camera",
                        status: permissions.camera,
                        actionTitle: actionTitle(for: permissions.camera)
                    ) {
                        handleCameraAction()
                    }

                    PermissionSettingsRow(
                        icon: "photo.on.rectangle",
                        title: "Photos",
                        status: permissions.photoLibrary,
                        actionTitle: actionTitle(
                            for: permissions.photoLibrary
                        )
                    ) {
                        handlePhotoLibraryAction()
                    }

                    PermissionSettingsRow(
                        icon: "location.fill",
                        title: "Location",
                        status: permissions.location,
                        actionTitle: actionTitle(
                            for: permissions.location
                        )
                    ) {
                        handleLocationAction()
                    }
                }

                if !requiresPermissionSetup {
                    Section {
                        Button {
                            showsPrivacy = true
                        } label: {
                            HStack(spacing: PhotoDomeTokens.Space.x3) {
                                Image(systemName: "hand.raised")
                                    .accessibilityHidden(true)
                                Text("Privacy and data")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .accessibilityHidden(true)
                            }
                            .foregroundStyle(AppTheme.ink)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle(
                requiresPermissionSetup ? "Permissions" : "Settings"
            )
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showsPrivacy) {
                PrivacyDetailsView()
            }
            .safeAreaInset(edge: .bottom) {
                if requiresPermissionSetup {
                    Button("Continue") {
                        dismiss()
                    }
                    .buttonStyle(MonochromeButtonStyle())
                    .disabled(!permissions.isReadyForSession)
                    .padding(.horizontal, AppTheme.pagePadding)
                    .padding(.vertical, PhotoDomeTokens.Space.x3)
                    .background(.ultraThinMaterial)
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(
                        requiresPermissionSetup ? "Cancel" : "Done"
                    )
                }
            }
        }
        .task { permissions.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                permissions.refresh()
            }
        }
    }

    private func actionTitle(
        for status: PhotoDomePermissionStatus
    ) -> String? {
        switch status {
        case .notDetermined:
            "Allow"
        case .denied, .restricted, .reducedAccuracy:
            "Open Settings"
        case .authorized, .unavailable:
            nil
        }
    }

    private func handleCameraAction() {
        switch permissions.camera {
        case .notDetermined:
            Task { await permissions.requestCamera() }
        case .denied, .restricted, .reducedAccuracy:
            permissions.openSystemSettings()
        case .authorized, .unavailable:
            break
        }
    }

    private func handlePhotoLibraryAction() {
        switch permissions.photoLibrary {
        case .notDetermined:
            Task { await permissions.requestPhotoLibrary() }
        case .denied, .restricted, .reducedAccuracy:
            permissions.openSystemSettings()
        case .authorized, .unavailable:
            break
        }
    }

    private func handleLocationAction() {
        switch permissions.location {
        case .notDetermined:
            permissions.requestLocation()
        case .denied, .restricted, .reducedAccuracy:
            permissions.openSystemSettings()
        case .authorized, .unavailable:
            break
        }
    }

}

private struct EditDisplayNameView: View {
    let onSave: (String) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var displayName: String
    @State private var isSaving = false
    @State private var validationMessage: String?
    @FocusState private var isFocused: Bool

    init(
        displayName: String,
        onSave: @escaping (String) async -> Bool
    ) {
        self.onSave = onSave
        _displayName = State(initialValue: displayName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PhotoDomeTokens.Space.x3) {
            TextField("Your name", text: $displayName)
                .textContentType(.name)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .focused($isFocused)
                .padding(16)
                .background(AppTheme.softFill)
                .clipShape(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                        .stroke(AppTheme.hairline)
                }
                .onChange(of: displayName) {
                    if displayName.count > 50 {
                        displayName = String(displayName.prefix(50))
                    }
                    validationMessage = nil
                }
                .onSubmit { save() }

            if let validationMessage {
                Text(validationMessage)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.ink)
            }

            Button {
                save()
            } label: {
                HStack {
                    Spacer()
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("Save")
                    }
                    Spacer()
                }
            }
            .buttonStyle(MonochromeButtonStyle())
            .disabled(isSaving)

            Spacer()
        }
        .padding(AppTheme.pagePadding)
        .background(AppTheme.canvas)
        .navigationTitle("Your name")
        .navigationBarTitleDisplayMode(.inline)
        .task { isFocused = true }
    }

    private func save() {
        let normalized = displayName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !normalized.isEmpty else {
            validationMessage = "Enter your name."
            isFocused = true
            return
        }
        guard !isSaving else { return }

        isSaving = true
        Task {
            if await onSave(normalized) {
                dismiss()
            } else {
                validationMessage = "Your name couldn’t be saved."
            }
            isSaving = false
        }
    }
}

private struct PrivacyDetailsView: View {
    var body: some View {
        List {
            Section {
                PrivacyRow(
                    icon: "person.crop.circle.badge.checkmark",
                    title: "No account",
                    detail:
                        "PhotoDome asks only for a display name so people in a session know who joined. No email, phone number, password, or social profile is required."
                )
                PrivacyRow(
                    icon: "lock.shield",
                    title: "Invite-only events",
                    detail:
                        "Only people with a valid invite or saved event access can open an event. Hosts can rotate the invite and remove attendees or photos."
                )
                PrivacyRow(
                    icon: "key.icloud",
                    title: "iCloud Keychain",
                    detail:
                        "Stores event access so it can recover on your Apple devices without a PhotoDome account."
                )
            } header: {
                sectionHeader("Private by default")
            }

            Section {
                Text(
                    "To run an event, PhotoDome stores its name, each participant’s display name, anonymous membership and access records, contributed photos, upload state, and each attendee’s private keep or skip choices."
                )
                Text(
                    "A random installation identifier supports reliable accountless requests and abuse protection. It is not an advertising identifier."
                )
            } header: {
                sectionHeader("What PhotoDome stores")
            }

            Section {
                Text(
                    "Contributed photos are stored in a private cloud bucket. PhotoDome preserves full-resolution visual quality and embedded metadata, including capture date, orientation, and GPS."
                )
                Text(
                    "PhotoDome requires Precise Location while you use its camera and adds the shutter-time coordinate to that photo. It does not request background location. Imported photos keep their existing metadata and are never stamped with your location at import time."
                )
                Text(
                    "Anyone with authorized access to the event can download a contributed master and receive its embedded location and other metadata."
                )
                Text(
                    "Seven days after the host ends an event, PhotoDome makes it unavailable and permanently deletes its cloud photos and server records. Copies already saved to an iPhone remain under that person’s control."
                )
            } header: {
                sectionHeader("Photos and retention")
            }

            Section {
                Text(
                    "This build has no advertising, cross-app tracking, or product analytics SDK. Operational logs and aggregate service-health metrics are used only to keep PhotoDome secure and reliable."
                )
            } header: {
                sectionHeader("Tracking and analytics")
            }

            Section {
                Text(
                    "The public privacy-policy URL, legal owner, and support contact are required before external TestFlight distribution and remain to be configured."
                )
                .font(.footnote)
                .foregroundStyle(AppTheme.secondaryInk)
            }
        }
        .navigationTitle("Privacy and data")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sectionHeader(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .foregroundStyle(AppTheme.ink)
    }
}

private struct PermissionSettingsRow: View {
    let icon: String
    let title: String
    let statusLabel: String
    let actionTitle: String?
    let action: (() -> Void)?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(
        icon: String,
        title: String,
        status: PhotoDomePermissionStatus,
        actionTitle: String?,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        statusLabel = status.label
        self.actionTitle = actionTitle
        self.action = action
    }

    init(
        icon: String,
        title: String,
        statusLabel: String
    ) {
        self.icon = icon
        self.title = title
        self.statusLabel = statusLabel
        actionTitle = nil
        action = nil
    }

    var body: some View {
        HStack(alignment: .top, spacing: PhotoDomeTokens.Space.x3) {
            Image(systemName: icon)
                .foregroundStyle(AppTheme.ink)
                .frame(width: PhotoDomeTokens.Size.largeIcon)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: PhotoDomeTokens.Space.x1) {
                if dynamicTypeSize.isAccessibilitySize {
                    Text(title)
                        .font(.headline)
                    Text(statusLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                } else {
                    HStack {
                        Text(title)
                            .font(.headline)
                        Spacer()
                        Text(statusLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.ink)
                    }
                }

                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .buttonStyle(.bordered)
                        .tint(AppTheme.ink)
                        .padding(.top, PhotoDomeTokens.Space.x1)
                }
            }
        }
        .padding(.vertical, PhotoDomeTokens.Space.x1)
    }
}

private struct PrivacyRow: View {
    let icon: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryInk)
            }
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(AppTheme.ink)
                .accessibilityHidden(true)
        }
    }
}
