import Foundation

public struct Location: Codable, Equatable, Sendable {
  public let file: String
  public let line: Int
}

public struct Reference: Codable, Equatable, Hashable, Sendable {
  public let spelling: String
  public let role: String
  public let member: String
  public let line: Int
}

public struct BodyMetrics: Codable, Equatable, Sendable {
  public var controlFlowSites = 0
  public var closures = 0
  public var tokens = 0
  public var explicitSelfAssignments = 0
}

public struct Member: Codable, Equatable, Sendable {
  public let key: String
  public let kind: String
  public let signature: String
  public let location: Location
  public var body: BodyMetrics?
  /// A syntactic shape, not a claim that the wrapper is unnecessary or has no effects.
  public var forwardingCall: String?
}

public struct TypeRecord: Codable, Equatable, Sendable {
  public let id: String
  public let name: String
  public let kind: String
  public let location: Location
  public let header: String
  public var members: [Member] = []
  public var references: [Reference] = []
  public var referencedTypeSpellings: [String] {
    Array(Set(references.map(\.spelling))).sorted()
  }
}

public struct Notice: Codable, Equatable, Sendable {
  public let location: Location
  public let message: String
}

public struct Snapshot: Encodable, Sendable {
  public let schemaVersion = 1
  public let analysis = "syntax-only"
  public var files = 0
  public var types: [TypeRecord] = []
  public var notices: [Notice] = []
  public let limitations = [
    "Type spellings are not resolved symbols or semantic dependency edges.",
    "Extensions are separate records; identities include file paths. Moves/renames appear as removal/addition.",
    "All conditional-compilation branches are parsed; macros are not expanded.",
    "Inferred types, call targets, module membership, purity and transitive effects are not resolved.",
    "No finding does not imply that the design is safe or unchanged.",
  ]
  public init() {}
}

public struct Finding: Codable, Sendable {
  public let rule: String
  public let type: String
  public let location: Location
  public let message: String
  public let before: [String]
  public let after: [String]
}

public struct DiffReport: Encodable, Sendable {
  public let schemaVersion = 1
  public let analysis = "syntax-only"
  public let beforeLabel: String
  public let afterLabel: String
  public let beforeFiles: Int
  public let afterFiles: Int
  public let findings: [Finding]
  public let notices: [Notice]
  public let limitations: [String]
}

public enum PatchworkError: Error, CustomStringConvertible {
  case message(String)
  public var description: String {
    switch self {
    case .message(let text): return text
    }
  }
}
