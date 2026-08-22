import Foundation

struct GraphQLRequestError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// Minimal hand-written GraphQL client (URLSession + Codable, no codegen) - mirrors
/// GraphQLClient.kt on the Android port. Auth (the "ApiKey" header) is added by the shared
/// URLSession, see StashURLSessionFactory.
final class GraphQLClient {
    private let baseURL: URL
    private let urlSession: URLSession
    private let decoder = JSONDecoder()

    init(baseURL: URL, urlSession: URLSession) {
        self.baseURL = baseURL
        self.urlSession = urlSession
    }

    func execute<T: Decodable>(
        query: String,
        variables: [String: Any] = [:],
        as type: T.Type
    ) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent("graphql"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["query": query, "variables": variables]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw GraphQLRequestError(message: "Erreur HTTP depuis le serveur Stash")
        }

        let decoded: GraphQLResponse<T>
        do {
            decoded = try decoder.decode(GraphQLResponse<T>.self, from: data)
        } catch {
            throw GraphQLRequestError(message: "Réponse invalide du serveur : \(error.localizedDescription)")
        }

        if let errors = decoded.errors, !errors.isEmpty {
            throw GraphQLRequestError(message: errors.map(\.message).joined(separator: "; "))
        }

        guard let value = decoded.data else {
            throw GraphQLRequestError(message: "Réponse vide du serveur")
        }
        return value
    }
}
