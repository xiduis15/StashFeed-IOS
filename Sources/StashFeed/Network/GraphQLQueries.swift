import Foundation

/// Raw GraphQL documents sent to the Stash server - identical to GraphQLQueries.kt on the
/// Android port, kept in sync deliberately.
enum GraphQLQueries {

    static let findScenesFeed = """
        query FindScenesFeed($page: Int!, $perPage: Int!, $sort: String!) {
          findScenes(filter: { page: $page, per_page: $perPage, sort: $sort, direction: ASC }) {
            count
            scenes {
              id
              title
              organized
              o_counter
              play_count
              resume_time
              files {
                width
                height
                duration
              }
              paths {
                screenshot
                stream
              }
              sceneStreams {
                url
                mime_type
                label
              }
            }
          }
        }
    """

    static let sceneAddO = """
        mutation AddSceneO($id: ID!) {
          sceneAddO(id: $id) {
            count
          }
        }
    """

    static let sceneDeleteO = """
        mutation DeleteSceneO($id: ID!) {
          sceneDeleteO(id: $id) {
            count
          }
        }
    """

    static let sceneAddPlay = """
        mutation AddScenePlay($id: ID!) {
          sceneAddPlay(id: $id) {
            count
          }
        }
    """

    static let sceneSetOrganized = """
        mutation SetSceneOrganized($id: ID!, $organized: Boolean!) {
          sceneUpdate(input: { id: $id, organized: $organized }) {
            id
            organized
          }
        }
    """

    static let sceneSaveActivity = """
        mutation SaveSceneActivity($id: ID!, $resumeTime: Float, $playDuration: Float) {
          sceneSaveActivity(id: $id, resume_time: $resumeTime, playDuration: $playDuration)
        }
    """
}
