import Foundation

/// Bundles every client built from the authenticated URLSession (GraphQL, repositories). Built
/// once after the user has entered valid server credentials. Mirrors StashSession.kt.
final class StashSession {
    let urlSession: URLSession
    let feedRepository: FeedRepository
    let actionsRepository: SceneActionsRepository

    private init(urlSession: URLSession, feedRepository: FeedRepository, actionsRepository: SceneActionsRepository) {
        self.urlSession = urlSession
        self.feedRepository = feedRepository
        self.actionsRepository = actionsRepository
    }

    static func create(credentials: ServerCredentials) -> StashSession? {
        guard let baseURL = URL(string: credentials.baseURL) else { return nil }
        let urlSession = StashURLSessionFactory.make(apiKey: credentials.apiKey)
        let client = GraphQLClient(baseURL: baseURL, urlSession: urlSession)
        return StashSession(
            urlSession: urlSession,
            feedRepository: FeedRepository(client: client),
            actionsRepository: SceneActionsRepository(client: client)
        )
    }
}
