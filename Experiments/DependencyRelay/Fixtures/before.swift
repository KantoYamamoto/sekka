struct Repository {
    init() {}
    func save() {}
}
struct EventSink {
    init() {}
    func record(_ event: String) {}
}
struct CheckoutScreen {
    let model: CheckoutModel
    init(repository: Repository) {
        model = CheckoutModel(repository: repository)
    }
}
struct CheckoutModel {
    let checkout: Checkout
    init(repository: Repository) {
        checkout = Checkout(repository: repository)
    }
}
struct Checkout {
    let repository: Repository
    init(repository: Repository) {
        self.repository = repository
    }
    func buy() { repository.save() }
}
