import Foundation

/// Sends a request and returns the body and HTTP status code. Tests swap in a fake.
@MainActor
protocol HTTPClient: AnyObject {
    func send(_ request: URLRequest) async throws -> (Data, Int)
}

final class URLSessionHTTPClient: HTTPClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func send(_ request: URLRequest) async throws -> (Data, Int) {
        let (data, response) = try await session.data(for: request)
        return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
    }
}
