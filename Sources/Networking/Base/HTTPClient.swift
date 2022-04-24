import Foundation

@available(iOS 15, *)
public protocol HTTPClient {
    func sendRequest<T: Decodable>(endpoint: Endpoint, responseModel: T.Type) async throws -> T
}

@available(iOS 15, *)
public extension HTTPClient {
    // TODO: Create the encoder to encode JSON or URL Encoder
    func sendRequest<T: Decodable>(
        endpoint: Endpoint,
        responseModel: T.Type
    ) async throws -> T {
        guard let url = URL(string: endpoint.baseURL) else {
            throw RequestError.invalidURL
        }
        var components = URLComponents(url: url.appendingPathComponent(endpoint.path), resolvingAgainstBaseURL: false)!
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = endpoint.method.rawValue
        request.allHTTPHeaderFields = endpoint.header
        
        switch endpoint.method {
        case .get, .delete:
            components.queryItems = mapURLQueryItems(params: endpoint.params)
            components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        case .post, .put, .patch:
            if let body = endpoint.params {
                request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
            }
        }
        request.url = components.url!
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw RequestError.noResponse
        }
        switch response.statusCode {
        case 200...299:
            return try JSONDecoder().decode(responseModel, from: data)
        case 401:
            throw RequestError.unauthorized
        default:
            throw RequestError.unexpectedStatusCode
        }
    }
}

private func mapURLQueryItems(params: [String: String]?) -> [URLQueryItem]? {
    guard let params = params else {
        return nil
    }
    return params.compactMap { key, value in
        URLQueryItem(name: key, value: value)
    }
}
