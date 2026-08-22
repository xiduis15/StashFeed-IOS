import Foundation

/// Field names here must match stash/graphql/schema/schema.graphql and
/// stash/graphql/schema/types/scene.graphql exactly (same contract as the Android port).

struct GraphQLError: Decodable {
    let message: String
}

struct GraphQLResponse<T: Decodable>: Decodable {
    let data: T?
    let errors: [GraphQLError]?
}

struct FindScenesData: Decodable {
    let findScenes: FindScenesResultDTO
}

struct FindScenesResultDTO: Decodable {
    let count: Int
    let scenes: [SceneDTO]
}

struct SceneDTO: Decodable {
    let id: String
    let title: String?
    let o_counter: Int?
    let play_count: Int?
    let resume_time: Double?
    let files: [VideoFileDTO]
    let paths: ScenePathsDTO?
    let sceneStreams: [SceneStreamDTO]
}

struct VideoFileDTO: Decodable {
    let width: Int
    let height: Int
    let duration: Double
}

struct ScenePathsDTO: Decodable {
    let screenshot: String?
    let stream: String?
}

struct SceneStreamDTO: Decodable {
    let url: String
    let mime_type: String?
    let label: String?
}

struct HistoryMutationResultDTO: Decodable {
    let count: Int
}

struct SceneAddOData: Decodable {
    let sceneAddO: HistoryMutationResultDTO
}

struct SceneDeleteOData: Decodable {
    let sceneDeleteO: HistoryMutationResultDTO
}

struct SceneAddPlayData: Decodable {
    let sceneAddPlay: HistoryMutationResultDTO
}

struct SceneSaveActivityData: Decodable {
    let sceneSaveActivity: Bool
}

struct TagDTO: Decodable {
    let id: String
    let name: String
}

struct FindTagsResultDTO: Decodable {
    let tags: [TagDTO]
}

struct FindTagsData: Decodable {
    let findTags: FindTagsResultDTO
}

struct PerformerDTO: Decodable {
    let id: String
    let name: String
}

struct FindPerformersResultDTO: Decodable {
    let performers: [PerformerDTO]
}

struct FindPerformersData: Decodable {
    let findPerformers: FindPerformersResultDTO
}
