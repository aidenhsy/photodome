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
                    Text("Scan or enter a code")
                        .font(.system(.title2, design: .rounded, weight: .bold))
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
                    TextField("Code", text: $code)
                        .font(
                            .system(
                                .title3,
                                design: .monospaced,
                                weight: .semibold
                            )
                        )
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)
                        .submitLabel(.join)
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
                            code = normalized(code)
                            validationMessage = nil
                        }
                        .onSubmit { submitCode() }

                    if let validationMessage {
                        Text(validationMessage)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.ink)
                    }
                }

                Button {
                    submitCode()
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
                guard !isWorking else { return }
                isWorking = true
                Task {
                    if await handlePayload(payload) {
                        dismiss()
                    } else {
                        isWorking = false
                    }
                }
            }
        }
    }

    private func normalized(_ value: String) -> String {
        String(
            value
                .uppercased()
                .filter { $0.isLetter || $0.isNumber }
                .prefix(8)
        )
    }

    private func submitCode() {
        guard !isWorking else { return }
        guard code.count == 8 else {
            validationMessage = "Enter the 8-character code."
            isCodeFocused = true
            return
        }

        isWorking = true
        Task {
            if await joinCode(code) { dismiss() }
            isWorking = false
        }
    }
}
