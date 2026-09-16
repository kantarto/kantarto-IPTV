import SwiftUI

struct AddProfileView: View {
    @EnvironmentObject private var profileStore: ProfileStore
    @Environment(\.dismiss) private var dismiss

    /// Pass an existing profile to edit it; nil to create a new one.
    var editingProfile: XtreamProfile?

    @State private var name: String = ""
    @State private var serverURL: String = ""
    @State private var username: String = ""
    @State private var password: String = ""

    @State private var isTesting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(editingProfile == nil ? "Νέα Xtream Playlist" : "Επεξεργασία Playlist")
                .font(.title2.bold())

            Form {
                TextField("Όνομα", text: $name)
                TextField("Server (π.χ. http://server:8080)", text: $serverURL)
                    .textContentType(.URL)
                TextField("Username", text: $username)
                SecureField("Password", text: $password)
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.callout)
            }

            HStack {
                if isTesting {
                    ProgressView().controlSize(.small)
                }
                Spacer()
                Button("Άκυρο") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(editingProfile == nil ? "Προσθήκη" : "Αποθήκευση") {
                    Task { await save() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || serverURL.isEmpty || username.isEmpty || password.isEmpty || isTesting)
            }
        }
        .padding(24)
        .frame(minWidth: 420)
        .onAppear(perform: prefillIfEditing)
    }

    private func prefillIfEditing() {
        guard let editingProfile else { return }
        name = editingProfile.name
        serverURL = editingProfile.serverURL
        username = editingProfile.username
        password = profileStore.password(for: editingProfile)
    }

    private func save() async {
        errorMessage = nil
        isTesting = true
        defer { isTesting = false }

        let candidate = XtreamProfile(
            id: editingProfile?.id ?? UUID(),
            name: name,
            serverURL: serverURL,
            username: username,
            password: password
        )
        let client = XtreamClient(profile: candidate, password: password)

        do {
            try await client.authenticate()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return
        }

        if let editingProfile {
            profileStore.updateProfile(editingProfile, name: name, serverURL: serverURL, username: username, password: password)
        } else {
            profileStore.addProfile(name: name, serverURL: serverURL, username: username, password: password)
        }
        dismiss()
    }
}
