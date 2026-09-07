// Synthetic input for checking PR-comment hierarchy; not an application design recommendation.
struct ReviewGuide {
    enum Format {
        case compact
        case detailed
    }

    var format: Format

    func title(for file: String) -> String {
        switch format {
        case .compact: return file
        case .detailed: return "Changed file: \(file)"
        }
    }
}
