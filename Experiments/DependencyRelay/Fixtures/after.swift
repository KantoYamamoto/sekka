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
    init(repository: Repository, events: EventSink) {
        model = CheckoutModel(repository: repository, events: events)
    }
}
struct CheckoutModel {
    let checkout: Checkout
    init(repository: Repository, events: EventSink) {
        checkout = Checkout(repository: repository, events: events)
    }
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
