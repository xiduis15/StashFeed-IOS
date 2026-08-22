import Foundation

/// Raw GraphQL documents sent to the Stash server - normally kept in sync deliberately with
/// GraphQLQueries.kt on the Android port. Filtering/sorting (findScenesFeed's `scene_filter`/
/// `direction`, findTags, findPerformers) and the removal of the `organized` field were done
/// iOS-first and still need porting back to Android.
enum GraphQLQueries {

    static let findScenesFeed = """
        query FindScenesFeed(
          $page: Int!
          $perPage: Int!
          $sort: String!
          $direction: SortDirectionEnum!
          $sceneFilter: SceneFilterType
        ) {
          findScenes(
            filter: { page: $page, per_page: $perPage, sort: $sort, direction: $direction }
            scene_filter: $sceneFilter
          ) {
            count
            scenes {
              id
              title
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

    static let findTags = """
        query FindTagsForFilter($q: String!, $perPage: Int!) {
          findTags(filter: { q: $q, per_page: $perPage }) {
            tags {
              id
              name
            }
          }
        }
    """

    static let findPerformers = """
        query FindPerformersForFilter($q: String!, $perPage: Int!) {
          findPerformers(filter: { q: $q, per_page: $perPage }) {
            performers {
              id
              name
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

    static let sceneSaveActivity = """
        mutation SaveSceneActivity($id: ID!, $resumeTime: Float, $playDuration: Float) {
          sceneSaveActivity(id: $id, resume_time: $resumeTime, playDuration: $playDuration)
        }
    """
}
