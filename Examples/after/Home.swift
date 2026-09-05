import SwiftUI

enum PaymentMethod {
    case cash
    case card(Card)
    case wallet
}

@MainActor
final class HomeViewModel {
    private let repository: ItemRepository
    private let analytics: AnalyticsService
    private let favorites: FavoriteRepository
    var title: String

    init(repository: ItemRepository, analytics: AnalyticsService, favorites: FavoriteRepository) {
        self.repository = repository
        self.analytics = analytics
        self.favorites = favorites
        self.title = "Home"
    }

    func purchase(_ item: Item) {
        if item.isPremium {
            analytics.track(item)
        }
        self.title = "Purchased"
        repository.save(item)
    }

    func track(_ event: Event) {
        analytics.track(event)
    }
}

struct HomeView: View {
    @State private var showFavorites = false
    @State private var showPromotion = false

    var body: some View {
        VStack {
            Text("Home")
            if showFavorites {
                Text("Favorites")
            }
            if showPromotion {
                Button("Dismiss") { showPromotion = false }
            }
        }
    }
}
