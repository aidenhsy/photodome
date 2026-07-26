import SwiftUI

struct PhotoReviewView: View {
    @StateObject private var model: PhotoReviewViewModel
    @ObservedObject private var downloads = PhotoDownloadManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragOffset: CGSize = .zero
    @State private var isStartingDownload = false

    init(access: StoredEventAccess) {
        _model = StateObject(
            wrappedValue: PhotoReviewViewModel(access: access)
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                if model.hasIncomingPhotos {
                    Label(
                        "New photos joined your remaining queue",
                        systemImage: "sparkles"
                    )
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryInk)
                }

                Group {
                    if let photo = model.currentPhoto {
                        reviewCard(photo)
                    } else if model.isLoading {
                        ProgressView()
                            .frame(maxHeight: .infinity)
                    } else {
                        completionState
                    }
                }
                .frame(maxHeight: .infinity)

                controls
            }
            .padding(AppTheme.pagePadding)
            .navigationTitle("Choose your photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            await downloads.configure()
            await model.bootstrap()
        }
        .onChange(of: savedPhotoIDs) { _, _ in
            Task { await model.refresh() }
        }
        .onDisappear { model.disconnect() }
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

    private var savedPhotoIDs: Set<String> {
        downloads.savedPhotoIDs(eventID: model.access.id)
    }

    private func reviewCard(_ photo: AlbumPhoto) -> some View {
        ZStack(alignment: .top) {
            AsyncImage(url: photo.displayURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                case .failure:
                    VStack(spacing: 12) {
                        ContentUnavailableView(
                            "Photo link expired",
                            systemImage: "photo"
                        )
                        Button("Reload photo") {
                            Task { await model.refresh() }
                        }
                        .buttonStyle(.bordered)
                        .tint(AppTheme.ink)
                    }
                default:
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.softFill)
            .clipShape(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
            )

            if abs(dragOffset.width) > 25 {
                Text(dragOffset.width > 0 ? "KEEP" : "SKIP")
                    .font(.system(.title2, design: .rounded, weight: .black))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(.white.opacity(0.9))
                    .clipShape(Capsule())
                    .padding(20)
            }
        }
        .offset(x: dragOffset.width, y: dragOffset.height * 0.2)
        .rotationEffect(
            .degrees(reduceMotion ? 0 : Double(dragOffset.width / 22))
        )
        .gesture(
            DragGesture()
                .onChanged { value in
                    guard !model.isSubmitting else { return }
                    dragOffset = value.translation
                }
                .onEnded { value in
                    let decision: PhotoSelectionDecision? =
                        if value.translation.width > 90 {
                            .keep
                        } else if value.translation.width < -90 {
                            .skip
                        } else {
                            nil
                        }
                    let reset = {
                        dragOffset = .zero
                    }
                    if reduceMotion {
                        reset()
                    } else {
                        withAnimation(.spring(response: 0.3), reset)
                    }
                    if let decision {
                        Task { await model.decide(decision) }
                    }
                }
        )
        .accessibilityLabel("Photo to review")
        .accessibilityHint("Swipe right to keep or left to skip")
    }

    private var completionState: some View {
        ContentUnavailableView(
            "You’re caught up",
            systemImage: "checkmark.circle"
        )
    }

    @ViewBuilder
    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                Task { await model.decide(.skip) }
            } label: {
                Label("Skip", systemImage: "xmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(OutlineButtonStyle())
            .disabled(model.currentPhoto == nil || model.isSubmitting)

            Button {
                Task { await model.undo() }
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .frame(width: 28)
            }
            .buttonStyle(OutlineButtonStyle())
            .disabled(model.decidedPhotoCount == 0 || model.isSubmitting)
            .accessibilityLabel("Undo latest choice")

            Button {
                Task { await model.decide(.keep) }
            } label: {
                Label("Keep", systemImage: "heart.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(MonochromeButtonStyle())
            .disabled(model.currentPhoto == nil || model.isSubmitting)
        }

        Button {
            Task {
                isStartingDownload = true
                defer { isStartingDownload = false }
                do {
                    try await downloads.start(
                        mode: .kept,
                        access: model.access
                    )
                } catch {
                    model.presentedError = error.photoDomeMessage
                }
            }
        } label: {
            if isStartingDownload {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                Text("Save kept photos")
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(OutlineButtonStyle())
        .disabled(model.keptPhotoCount == 0 || isStartingDownload)
    }
}
