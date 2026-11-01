//
//  VersionCheckClient.swift
//  DiskArchive
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
        await fetchOutcome(session: session, url: url).response
    }

    /// bug.0.4.145: Antwort und Grund des Scheiterns – `offline` = keine Verbindung (kein Versuch beim Server).
    static func fetchOutcome(
        session: URLSession = .shared,
        url: URL = VersionCheckEndpoint.url
    ) async -> (response: VersionCheckResponse?, offline: Bool) {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return (nil, false) }
            guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let raw = object["version"] as? String,
                  let version = AppVersion.parse(raw) else { return (nil, false) }
            return (VersionCheckResponse(version: version), false)
        } catch {
            return (nil, (error as? URLError)?.code == .notConnectedToInternet)
        }
    }
}
