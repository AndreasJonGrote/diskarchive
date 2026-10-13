//
//  VersionCheckClient.swift
//  diskindex
//
//  GET /api/version/ (c.0.3.3.001).
//

import Foundation

nonisolated enum VersionCheckEndpoint {
    #if DEBUG
    static let url = URL(string: "https://diskarchive.app/api/version/")!
    #else
    static let url = URL(string: "https://diskarchive.app/api/version/")!
    #endif
}

nonisolated struct VersionCheckResponse: Equatable, Sendable {
    var version: AppVersion
}

nonisolated enum VersionCheckClient {
    static func fetch(session: URLSession = .shared, url: URL = VersionCheckEndpoint.url) async -> VersionCheckResponse? {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }
            guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let raw = object["version"] as? String,
                  let version = AppVersion.parse(raw) else { return nil }
            return VersionCheckResponse(version: version)
        } catch {
            return nil
        }
    }
}
