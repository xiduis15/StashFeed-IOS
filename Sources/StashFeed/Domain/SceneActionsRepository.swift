import Foundation

/// "Instagram-like" actions mapped onto Stash mutations (see the port plan for the mapping
/// rationale). Mirrors SceneActionsRepository.kt.
final class SceneActionsRepository {
    private let client: GraphQLClient

    init(client: GraphQLClient) {
        self.client = client
    }

    /// Double-tap "like" -> increments Stash's O-counter for the scene.
    func addO(sceneId: String) async throws -> Int {
        let data = try await client.execute(
            query: GraphQLQueries.sceneAddO,
            variables: ["id": sceneId],
            as: SceneAddOData.self
        )
        return data.sceneAddO.count
    }

    /// Tap the drop icon "undo/error" -> decrements Stash's O-counter for the scene.
    func deleteO(sceneId: String) async throws -> Int {
        let data = try await client.execute(
            query: GraphQLQueries.sceneDeleteO,
            variables: ["id": sceneId],
            as: SceneDeleteOData.self
        )
        return data.sceneDeleteO.count
    }

    /// Counted once a scene has been watched for more than 10 seconds.
    func addPlay(sceneId: String) async throws -> Int {
        let data = try await client.execute(
            query: GraphQLQueries.sceneAddPlay,
            variables: ["id": sceneId],
            as: SceneAddPlayData.self
        )
        return data.sceneAddPlay.count
    }

    /// Bookmark/save toggle -> Stash's "organized" flag.
    func setOrganized(sceneId: String, organized: Bool) async throws -> Bool {
        let data = try await client.execute(
            query: GraphQLQueries.sceneSetOrganized,
            variables: ["id": sceneId, "organized": organized],
            as: SceneUpdateOrganizedData.self
        )
        return data.sceneUpdate?.organized ?? organized
    }

    /// Persists playback position so the scene can resume where the user left off.
    func saveActivity(sceneId: String, resumeTimeSeconds: Double, playDurationSeconds: Double) async throws {
        _ = try await client.execute(
            query: GraphQLQueries.sceneSaveActivity,
            variables: [
                "id": sceneId,
                "resumeTime": resumeTimeSeconds,
                "playDuration": playDurationSeconds,
            ],
            as: SceneSaveActivityData.self
        )
    }
}
