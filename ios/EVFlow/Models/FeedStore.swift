import Foundation
import Observation

/// Downloads the server-calibrated feed, keeps the last good copy in Caches and refreshes every 3 min.
/// The app has no prediction model of its own: everything comes from here.
@Observable @MainActor
final class FeedStore {
    private(set) var feed: Feed?
    /// last refresh failed (network / decode); old data stays on screen
    private(set) var failed = false

    @ObservationIgnored var onUpdate: ((Feed) -> Void)?
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var inFlight = false

    static let interval: Duration = .seconds(180)

    nonisolated private static var cacheURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("stations.json")
    }

    /// Show the cached (or bundled) feed immediately, then keep it fresh while the app is open.
    func start() {
        guard loop == nil else { return }
        loop = Task { [weak self] in
            await self?.loadCached()
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: Self.interval)
            }
        }
    }

    func refresh() async {
        guard !inFlight else { return }
        inFlight = true
        defer { inFlight = false }
        var comps = URLComponents(url: Feed.url, resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "t", value: String(Int(Date.now.timeIntervalSince1970)))] // bust GitHub's CDN cache
        let req = URLRequest(url: comps.url!, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse, http.statusCode != 200 { throw URLError(.badServerResponse) }
            let new = try await Task.detached(priority: .userInitiated) { try Feed.decode(data) }.value
            failed = false
            guard feed.map({ new.meta.dataUntilUtc > $0.meta.dataUntilUtc }) ?? true else { return }
            apply(new)
            let cache = Self.cacheURL
            Task.detached(priority: .utility) { try? data.write(to: cache, options: .atomic) }
        } catch {
            failed = true
        }
    }

    /// Caches copy from the last successful download, else the snapshot bundled with the app (first launch offline).
    private func loadCached() async {
        let cached = Self.cacheURL
        let bundled = Bundle.main.url(forResource: "stations", withExtension: "json")
        let f = await Task.detached(priority: .userInitiated) { () -> Feed? in
            for url in [cached, bundled].compactMap({ $0 }) {
                if let d = try? Data(contentsOf: url), let f = try? Feed.decode(d) { return f }
            }
            return nil
        }.value
        if let f, feed == nil { apply(f) }
    }

    private func apply(_ f: Feed) {
        feed = f
        onUpdate?(f)
    }
}
