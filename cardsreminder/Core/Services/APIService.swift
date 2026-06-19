import FirebaseAuth
import Foundation

enum APIError: LocalizedError {
    case notAuthenticated
    case invalidResponse
    case decodingFailed(String)
    case serverError(statusCode: Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return String(localized: "error_no_session")
        case .invalidResponse:
            return String(localized: "error_invalid_response")
        case .decodingFailed(let detail):
            return String(format: String(localized: "error_decoding_response"), detail)
        case .serverError(let code, let message):
            return message ?? String(format: String(localized: "error_server"), code)
        }
    }
}

struct APIService {
    static let shared = APIService()

    var baseURL = URL(string: "https://cards-reminder-api-production.up.railway.app")!

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            let withFractional = ISO8601DateFormatter()
            withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = withFractional.date(from: value) { return date }

            let standard = ISO8601DateFormatter()
            standard.formatOptions = [.withInternetDateTime]
            if let date = standard.date(from: value) { return date }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid date: \(value)"
            )
        }
        return decoder
    }()

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    func request<T: Decodable>(
        path: String,
        method: String = "GET",
        body: (any Encodable)? = nil
    ) async throws -> T {
        let data = try await performRequest(path: path, method: method, body: body)
        do {
            return try decoder.decode(T.self, from: data)
        } catch let error as DecodingError {
            throw APIError.decodingFailed(Self.decodingErrorDescription(error))
        } catch {
            throw APIError.decodingFailed(error.localizedDescription)
        }
    }

    func requestVoid(
        path: String,
        method: String = "DELETE",
        body: (any Encodable)? = nil
    ) async throws {
        _ = try await performRequest(path: path, method: method, body: body)
    }

    private static func decodingErrorDescription(_ error: DecodingError) -> String {
        switch error {
        case .keyNotFound(let key, let context):
            return "Falta el campo '\(key.stringValue)' (\(context.debugDescription))"
        case .typeMismatch(let type, let context):
            return "Tipo incorrecto para '\(context.codingPath.map(\.stringValue).joined(separator: "."))': se esperaba \(type) (\(context.debugDescription))"
        case .valueNotFound(let type, let context):
            return "Valor nulo inesperado para '\(context.codingPath.map(\.stringValue).joined(separator: "."))': se esperaba \(type) (\(context.debugDescription))"
        case .dataCorrupted(let context):
            return context.debugDescription
        @unknown default:
            return error.localizedDescription
        }
    }

    private func performRequest(
        path: String,
        method: String,
        body: (any Encodable)?
    ) async throws -> Data {
        let urlRequest = try await authorizedRequest(path: path, method: method, body: body)
        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = Self.parseServerErrorMessage(from: data)
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: message)
        }

        return data
    }

    private func authorizedRequest(
        path: String,
        method: String,
        body: (any Encodable)?
    ) async throws -> URLRequest {
        guard let firebaseUser = Auth.auth().currentUser else {
            throw APIError.notAuthenticated
        }

        let token = try await firebaseUser.getIDToken()
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw APIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(Self.acceptLanguageHeaderValue, forHTTPHeaderField: "Accept-Language")

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encoder.encode(body)
        }

        return request
    }

    private static var acceptLanguageHeaderValue: String {
        Locale.current.language.languageCode?.identifier ?? "es"
    }

    private struct APIErrorBody: Decodable {
        let error: String?
        let message: String?

        var text: String? {
            if let error, !error.isEmpty { return error }
            if let message, !message.isEmpty { return message }
            return nil
        }
    }

    private static func parseServerErrorMessage(from data: Data) -> String? {
        if data.isEmpty { return nil }

        if let body = try? JSONDecoder().decode(APIErrorBody.self, from: data),
           let text = body.text?.trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty {
            return text
        }

        let raw = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let raw, !raw.isEmpty else { return nil }
        if raw.hasPrefix("{") || raw.hasPrefix("[") { return nil }
        return raw
    }
}
