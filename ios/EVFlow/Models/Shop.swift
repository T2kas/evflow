import Foundation

/// A prize from the Arbus shop (Supabase `shop_products`, public read-only).
struct ShopProduct: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String?
    let priceCredits: Int
    let category: String?
    let isFeatured: Bool?
    let imageUrl: String?
    let description: String?

    enum CodingKeys: String, CodingKey {
        case id, title, subtitle, category, description
        case priceCredits = "price_credits", isFeatured = "is_featured", imageUrl = "image_url"
    }

    /// price in EVFlow points
    var points: Int { max(10, priceCredits / Rewards.creditsPerPoint) }
    var image: URL? { imageUrl.flatMap(URL.init(string:)) }
}

/// Loads the Arbus shop: cached / bundled snapshot first, then a live refresh.
@MainActor
final class ShopStore: ObservableObject {
    @Published private(set) var products: [ShopProduct] = []

    private static let endpoint = URL(string: "https://crwtwtwljqypvgvvfmyo.supabase.co/rest/v1/shop_products?select=id,title,subtitle,price_credits,category,is_featured,image_url,description&active=eq.true&order=is_featured.desc,sort_order.asc")!
    /// Supabase publishable key: read-only through RLS (anon may only SELECT shop_products)
    private static let publishableKey = "sb_publishable_QeF6O9LaBazVtQH6CQzokQ_swcIvfCs"
    private static var cacheURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("shop.json")
    }

    func load() async {
        if products.isEmpty {
            for url in [Self.cacheURL, Bundle.main.url(forResource: "shop_snapshot", withExtension: "json")].compactMap({ $0 }) {
                if let d = try? Data(contentsOf: url), let p = try? JSONDecoder().decode([ShopProduct].self, from: d), !p.isEmpty {
                    products = p; prefetch(); break
                }
            }
        }
        var req = URLRequest(url: Self.endpoint, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        req.setValue(Self.publishableKey, forHTTPHeaderField: "apikey")
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let fresh = try? JSONDecoder().decode([ShopProduct].self, from: data), !fresh.isEmpty else { return }
        products = fresh
        prefetch()
        try? data.write(to: Self.cacheURL, options: .atomic)
    }

    /// warm the first screens' worth of card images
    private func prefetch() { ImageCache.shared.prefetch(products.prefix(24).compactMap(\.image)) }
}
