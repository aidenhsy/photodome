import SwiftUI

struct CreateEventView: View {
    let onCreate: (String) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var isWorking = false
    @State private var validationMessage: String?
    @FocusState private var isNameFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Name")
                            .font(.headline)
                            .lineLimit(nil)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        TextField("", text: $name)
                            .accessibilityLabel("Event name")
                            .textInputAutocapitalization(.words)
                            .focused($isNameFocused)
                            .padding(12)
                            .background(AppTheme.softFill)
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: AppTheme.cornerRadius
                                )
                            )
                            .overlay {
                                RoundedRectangle(
                                    cornerRadius: AppTheme.cornerRadius
                                )
                                .stroke(AppTheme.hairline)
                            }
                            .onChange(of: name) {
                                if !name.trimmingCharacters(
                                    in: .whitespacesAndNewlines
                                ).isEmpty {
                                    validationMessage = nil
                                }
                            }
                        if let validationMessage {
                            Text(validationMessage)
                                .font(.footnote)
                                .foregroundStyle(AppTheme.ink)
                                .accessibilityLabel(validationMessage)
                        }
                    }

                    Button {
                        let trimmedName = name.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )
                        guard !trimmedName.isEmpty else {
                            validationMessage = "Enter an event name."
                            isNameFocused = true
                            return
                        }
                        isWorking = true
                        Task {
                            if await onCreate(trimmedName) {
                                dismiss()
                            }
                            isWorking = false
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Text("Create")
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                            if isWorking { ProgressView() }
                            Spacer()
                        }
                    }
                    .accessibilityLabel("Create event")
                    .disabled(isWorking)
                    .buttonStyle(MonochromeButtonStyle())
                }
                .padding(AppTheme.pagePadding)
            }
            .background(AppTheme.canvas)
            .navigationTitle("New event")
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
        .presentationDetents([.medium, .large])
    }
}
