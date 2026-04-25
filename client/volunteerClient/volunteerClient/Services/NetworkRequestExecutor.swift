import Foundation

enum NetworkRequestExecutor {
    static func data(
        for request: URLRequest,
        session: URLSession,
        retries: Int = 1
    ) async throws -> (Data, URLResponse) {
        var preparedRequest = request
        preparedRequest.cachePolicy = .reloadIgnoringLocalCacheData
        preparedRequest.timeoutInterval = preparedRequest.timeoutInterval == 60
            ? 30
            : preparedRequest.timeoutInterval
        preparedRequest.setValue("close", forHTTPHeaderField: "Connection")

        do {
            return try await session.data(for: preparedRequest)
        } catch {
            guard retries > 0, error.isTransientNetworkError else {
                throw error
            }

            try? await Task.sleep(nanoseconds: 300_000_000)
            return try await data(for: preparedRequest, session: session, retries: retries - 1)
        }
    }

    static func data(
        from url: URL,
        session: URLSession,
        retries: Int = 1
    ) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        return try await data(for: request, session: session, retries: retries)
    }
}

extension Error {
    var isTransientNetworkError: Bool {
        guard let urlError = self as? URLError else { return false }

        switch urlError.code {
        case .networkConnectionLost,
             .cannotConnectToHost,
             .cannotFindHost,
             .dnsLookupFailed,
             .timedOut:
            return true
        default:
            return false
        }
    }

    var isUnauthorizedResponse: Bool {
        if let error = self as? AppNetworkError,
           case .unauthorized = error {
            return true
        }

        if let error = self as? EventAPIError,
           case .unauthorized = error {
            return true
        }

        return (self as NSError).code == 401
    }
}
