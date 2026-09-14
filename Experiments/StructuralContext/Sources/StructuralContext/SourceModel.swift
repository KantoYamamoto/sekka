public struct SourceSite: Codable, Equatable, Sendable {
  public let file: String
  public let line: Int
  public let endLine: Int
  public let declaration: String
  public let signature: String?
}

public enum ContextError: Error { case malformed(String) }
