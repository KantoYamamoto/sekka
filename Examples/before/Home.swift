import SwiftUI

// Fixtures are parsed, not built. SDKs and dependency implementations are unnecessary.
enum PaymentMethod {
    case cash
}

@MainActor
final class HomeViewModel {
    private let repository: ItemRepository
    var title: String

    init(repository: ItemRepository) {
        self.repository = repository
        self.title = "Home"
    }

    func purchase(_ item: Item) {
        repository.save(item)
    }
}

struct HomeView: View {
    var body: some View {
        VStack {
            Text("Home")
        }
    }
}
