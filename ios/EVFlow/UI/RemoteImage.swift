import SwiftUI
import UIKit

/// Shared image cache for the shop: decoded thumbnails in memory, raw responses on disk (URLCache),
/// one download per URL even when several views ask at once.
@MainActor
final class ImageCache {
    static let shared = ImageCache()
    private let memory = NSCache<NSURL, UIImage>()
    private var inFlight: [URL: Task<UIImage?, Never>] = [:]
    private let session: URLSession = {
        let c = URLSessionConfiguration.default
        c.urlCache = URLCache(memoryCapacity: 32 << 20, diskCapacity: 200 << 20)
        c.requestCachePolicy = .returnCacheDataElseLoad
        return URLSession(configuration: c)
    }()

    func cached(_ url: URL?) -> UIImage? { url.flatMap { memory.object(forKey: $0 as NSURL) } }

    func load(_ url: URL) async -> UIImage? {
        if let img = cached(url) { return img }
        if let t = inFlight[url] { return await t.value }
        let session = self.session
        let t = Task<UIImage?, Never>.detached(priority: .userInitiated) {
            guard let (data, _) = try? await session.data(from: url), let img = UIImage(data: data) else { return nil }
            // card images are ~128 pt: keep a 3× thumbnail, not the full upload
            return img.preparingThumbnail(of: CGSize(width: 400, height: 400)) ?? img
        }
        inFlight[url] = t
        let img = await t.value
        inFlight[url] = nil
        if let img { memory.setObject(img, forKey: url as NSURL) }
        return img
    }

    func prefetch(_ urls: [URL]) {
        for u in urls where cached(u) == nil && inFlight[u] == nil { Task { _ = await load(u) } }
    }
}

/// Cached remote image with a soft placeholder and a quick fade-in.
struct RemoteImage: View {
    let url: URL?
    @State private var image: UIImage?

    init(url: URL?) {
        self.url = url
        _image = State(initialValue: ImageCache.shared.cached(url))
    }

    var body: some View {
        ZStack {
            W.field
            if url == nil { GlyphView(.gift, size: 34, color: W.text3) } // product without a photo
            if let image {
                Image(uiImage: image).resizable().scaledToFill().transition(.opacity)
            }
        }
        .task(id: url) {
            guard image == nil, let url else { return }
            let img = await ImageCache.shared.load(url)
            withAnimation(.easeOut(duration: 0.2)) { image = img }
        }
    }
}
