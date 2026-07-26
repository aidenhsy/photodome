import SwiftUI

struct JoinEventView: View {
    let joinCode: (String) async -> Bool
    let handlePayload: (InvitePayload) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var isWorking = false
    @State private var showsScanner = false
    @State private var validationMessage: String?
    @FocusState private var isCodeFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.largeTitle.weight(.light))
                        .accessibilityHidden(true)
                    Text("Join without an account")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .frame(maxWidth: .infinity)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Scan the host’s QR or enter the 8-character code.")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(AppTheme.secondaryInk)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .frame(maxWidth: .infinity)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button("Scan QR code") {
                    showsScanner = true
                }
                .buttonStyle(MonochromeButtonStyle())

                HStack {
                    Rectangle().fill(AppTheme.hairline).frame(height: 1)
                    Text("OR").font(AppTheme.eyebrow)
                        .foregroundStyle(AppTheme.secondaryInk)
                    Rectangle().fill(AppTheme.hairline).frame(height: 1)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Event code")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    TextField("", text: $code)
                        .font(
                            .system(
                                .title3,
                                design: .monospaced,
                                weight: .semibold
                            )
                        )
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .multilineTextAlignment(.center)
                        .padding(16)
                        .background(AppTheme.softFill)
                        .clipShape(
                            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                        )
                        .accessibilityLabel("Event code")
                        .accessibilityHint(
                            "Enter the 8-character code from the host"
                        )
                        .focused($isCodeFocused)
                        .onChange(of: code) {
                            if !code.trimmingCharacters(
                                in: .whitespacesAndNewlines
                            ).isEmpty {
                                validationMessage = nil
                            }
                        }
                    if let validationMessage {
                        Text(validationMessage)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.ink)
                    }
                }

                Button {
                    let trimmedCode = code.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                    guard !trimmedCode.isEmpty else {
                        validationMessage = "Enter an event code."
                        isCodeFocused = true
                        return
                    }
                    isWorking = true
                    Task {
                        if await joinCode(trimmedCode) { dismiss() }
                        isWorking = false
                    }
                } label: {
                    if isWorking {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Join event").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(OutlineButtonStyle())
                .disabled(isWorking)

                Spacer()
            }
            .padding(AppTheme.pagePadding)
            .navigationTitle("Join")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Cancel")
                }
            }
        }
        .sheet(isPresented: $showsScanner) {
            QRScannerView { payload in
                Task {
                    if await handlePayload(payload) { dismiss() }
                }
            }
        }
    }
}
