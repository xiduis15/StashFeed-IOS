import Foundation

/// Builds the single URLSession shared by GraphQL calls, poster image loading, and video
/// playback (AVPlayer reads its headers from this same configuration), so authentication is
/// defined in exactly one place.
///
/// IMPORTANT: unlike the scene stream URL (which Stash appends "?apikey=" to when the server has
/// no username/password configured, or a signed URL when it does), the screenshot/preview/webp
/// paths only accept the "ApiKey" HTTP header, never a query param. Since this app has no browser
/// session/cookie, every request must carry that header - `httpAdditionalHeaders` applies it
/// automatically to every request made through this session.
enum StashURLSessionFactory {
    static func make(apiKey: String) -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = ["ApiKey": apiKey]
        configuration.urlCache = URLCache(
            memoryCapacity: 20 * 1024 * 1024,
            diskCapacity: 200 * 1024 * 1024
        )
        configuration.requestCachePolicy = .useProtocolCachePolicy
        configuration.timeoutIntervalForRequest = 30
        return URLSession(configuration: configuration)
    }
}
