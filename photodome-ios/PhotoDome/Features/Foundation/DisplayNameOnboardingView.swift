import SwiftUI

struct DisplayNameOnboardingView: View {
    @ObservedObject var profile: DeviceProfile
    let onBack: () -> Void

    @State private var name = ""
    @State private var isSaving = false
    @FocusState private var isNameFocused: Bool

    var body: some View {
        ZStack {
            AppTheme.canvas.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.title3.weight(.semibold))
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Back")

                    Spacer()
                }

                Spacer()

                Text("What’s your name?")
                    .font(
                        .system(
                            .largeTitle,
                            design: .rounded,
                            weight: .bold
                        )
                    )

                Text("People in your sessions will see it.")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(AppTheme.secondaryInk)

                TextField("Your name", text: $name)
                    .textContentType(.name)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.continue)
                    .focused($isNameFocused)
                    .padding(16)
                    .background(AppTheme.softFill)
                    .clipShape(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    )
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: AppTheme.cornerRadius
                        )
                        .stroke(AppTheme.hairline)
                    }
                    .onChange(of: name) {
                        if name.count > 50 {
                            name = String(name.prefix(50))
                        }
                    }
                    .onSubmit { save() }

                if let errorMessage = profile.errorMessage {
                    Text(errorMessage)
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
                            Text("Continue")
                        }
                        Spacer()
                    }
                }
                .buttonStyle(MonochromeButtonStyle())
                .accessibilityIdentifier("nameContinueButton")
                .disabled(
                    isSaving
                        || name.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty
                )

                Spacer()
            }
            .padding(AppTheme.pagePadding)
        }
        .task {
            isNameFocused = true
        }
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        Task {
            _ = await profile.save(name)
            isSaving = false
        }
    }
}
