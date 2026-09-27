/// A written lexical container, not a resolved Swift type or active compilation scope.
public struct InventoryScope: Codable, Sendable {
  public let id: String
  public let kind: String
  public let writtenOwner: String
  public let headerTokens: String
  public let site: SourceSite
}

/// Length prefixes preserve tuple boundaries even when Swift tokens contain separators.
func inventoryKey(_ parts: [String]) -> String {
  parts.map { "\($0.utf8.count):" + $0 }.joined()
}
