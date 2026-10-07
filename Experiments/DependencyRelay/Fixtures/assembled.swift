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
    init(model: CheckoutModel) { self.model = model }
}
struct CheckoutModel {
    let checkout: Checkout
    init(checkout: Checkout) { self.checkout = checkout }
}
struct Checkout {
    let repository: Repository
    let events: EventSink
    init(repository: Repository, events: EventSink) {
        self.repository = repository
        self.events = events
    }
    func buy() {
        repository.save()
        events.record("purchase")
    }
}
func assemble(repository: Repository, events: EventSink) -> CheckoutScreen {
    CheckoutScreen(model: CheckoutModel(checkout: Checkout(repository: repository, events: events)))
}
