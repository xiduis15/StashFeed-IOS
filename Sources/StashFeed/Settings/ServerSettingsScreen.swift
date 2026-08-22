import SwiftUI

/// Connection screen: server URL + API key. Mirrors ServerSettingsScreen.kt.
struct ServerSettingsScreen: View {
    let settingsStore: ServerSettingsStore
    let onConnected: (StashSession) -> Void

    @State private var baseURL = "http://"
    @State private var apiKey = ""
    @State private var isConnecting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Connexion à Stash")
                .font(.title2)
                .bold()

            TextField("URL du serveur (ex: http://192.168.1.10:9999)", text: $baseURL)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .keyboardType(.URL)

            TextField("Clé API (Settings > Security dans Stash)", text: $apiKey)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                .disableAutocorrection(true)

            if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
            }

            Button {
                connect()
            } label: {
                if isConnecting {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Se connecter")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isConnecting || baseURL.isEmpty || apiKey.isEmpty)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    private func connect() {
        let trimmedURLRaw = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = trimmedURLRaw.hasSuffix("/") ? String(trimmedURLRaw.dropLast()) : trimmedURLRaw
        let cleanedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        isConnecting = true
        errorMessage = nil

        Task {
            defer { isConnecting = false }

            guard let session = StashSession.create(
                credentials: ServerCredentials(baseURL: trimmedURL, apiKey: cleanedKey)
            ) else {
                errorMessage = "URL de serveur invalide"
                return
            }

            do {
                // Cheap query used purely to validate the URL/key before persisting them.
                _ = try await session.feedRepository.loadPage(
                    page: 1,
                    perPage: 1,
                    sort: .random,
                    filter: SceneFeedFilter()
                )
                settingsStore.saveCredentials(baseURL: trimmedURL, apiKey: cleanedKey)
                onConnected(session)
            } catch {
                errorMessage = "Connexion impossible : \(error.localizedDescription)"
            }
        }
    }
}
