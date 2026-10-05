import Foundation
import WebKit

struct WebsiteCookieScope: Identifiable {
    let id = UUID()
    let hosts: [String]

    init(urls: [URL]) {
        hosts = Array(Set(urls.filter { ["http", "https"].contains($0.scheme?.lowercased() ?? "") }
            .compactMap(\.host).map { $0.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".")) }
            .filter { !$0.isEmpty })).sorted()
    }

    func includes(domain: String) -> Bool {
        let domain = domain.lowercased()
        let isDomainCookie = domain.hasPrefix(".")
        let normalized = domain.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        guard !normalized.isEmpty else { return false }
        return hosts.contains { host in
            host == normalized || (isDomainCookie && host.hasSuffix("." + normalized))
        }
    }
}

@MainActor
final class WebsiteCookieService {
    // Keep the data store alive, and use the same store for previews and their widgets.
    let dataStore: WKWebsiteDataStore
    init(dataStore: WKWebsiteDataStore) { self.dataStore = dataStore }

    struct Result {
        let deleted: Int
        let remaining: Int
    }

    func clear(_ scope: WebsiteCookieScope) async -> Result {
        let store = dataStore.httpCookieStore
        let cookies = await store.allCookies().filter { scope.includes(domain: $0.domain) }
        for cookie in cookies { await store.deleteCookie(cookie) }
        let remaining = await store.allCookies().filter { scope.includes(domain: $0.domain) }.count
        return Result(deleted: cookies.count, remaining: remaining)
    }
}
