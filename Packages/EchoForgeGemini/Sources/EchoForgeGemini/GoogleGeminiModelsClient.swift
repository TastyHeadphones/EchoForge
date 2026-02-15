import Foundation

public struct GeminiModelDescriptor: Sendable, Hashable, Identifiable {
    public var id: String
    public var displayName: String?
    public var description: String?
    public var supportedGenerationMethods: [String]

    public init(
        id: String,
        displayName: String? = nil,
        description: String? = nil,
        supportedGenerationMethods: [String] = []
    ) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.supportedGenerationMethods = supportedGenerationMethods
    }
}

public protocol GeminiModelsListing: Sendable {
    func listModels(
        apiKey: String,
        apiVersion: String,
        baseURL: URL
    ) async throws -> [GeminiModelDescriptor]
}

public struct GoogleGeminiModelsClient: GeminiModelsListing {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func listModels(
        apiKey: String,
        apiVersion: String = "v1beta",
        baseURL: URL = URL(string: "https://generativelanguage.googleapis.com")!
    ) async throws -> [GeminiModelDescriptor] {
        let apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            throw GeminiModelsClientError.missingAPIKey
        }

        var pageToken: String?
        var models: [GeminiModelDescriptor] = []

        repeat {
            let url = try makeListModelsURL(
                apiVersion: apiVersion,
                baseURL: baseURL,
                pageToken: pageToken
            )

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw GeminiModelsClientError.invalidHTTPResponse
            }

            guard (200..<300).contains(http.statusCode) else {
                let body = String(data: data, encoding: .utf8)
                throw GeminiModelsClientError.httpError(statusCode: http.statusCode, body: body)
            }

            let decoded = try JSONDecoder().decode(ListModelsResponse.self, from: data)
            let page = decoded.models ?? []

            models.append(contentsOf: page.compactMap { resource in
                guard resource.name.hasPrefix("models/") else { return nil }
                let id = resource.name.replacingOccurrences(of: "models/", with: "")
                let methods = resource.supportedGenerationMethods ?? []

                return GeminiModelDescriptor(
                    id: id,
                    displayName: resource.displayName,
                    description: resource.description,
                    supportedGenerationMethods: methods
                )
            })

            pageToken = decoded.nextPageToken
        } while pageToken?.isEmpty == false

        return models.sorted(by: { $0.id < $1.id })
    }

    private func makeListModelsURL(
        apiVersion: String,
        baseURL: URL,
        pageToken: String?
    ) throws -> URL {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.path = "/\(apiVersion)/models"

        var items: [URLQueryItem] = []
        if let pageToken, !pageToken.isEmpty {
            items.append(URLQueryItem(name: "pageToken", value: pageToken))
        }
        components?.queryItems = items

        guard let url = components?.url else {
            throw GeminiModelsClientError.invalidURL
        }
        return url
    }
}

public enum GeminiModelsClientError: LocalizedError, Sendable {
    case missingAPIKey
    case invalidURL
    case invalidHTTPResponse
    case httpError(statusCode: Int, body: String?)

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Gemini API key is missing."
        case .invalidURL:
            return "Invalid Gemini models endpoint URL."
        case .invalidHTTPResponse:
            return "Invalid HTTP response from Gemini."
        case let .httpError(statusCode, body):
            if let body, !body.isEmpty {
                return "Gemini models request failed (HTTP \(statusCode)): \(body)"
            }
            return "Gemini models request failed (HTTP \(statusCode))."
        }
    }
}

private struct ListModelsResponse: Decodable {
    let models: [ModelResource]?
    let nextPageToken: String?
}

private struct ModelResource: Decodable {
    let name: String
    let displayName: String?
    let description: String?
    let supportedGenerationMethods: [String]?
}
