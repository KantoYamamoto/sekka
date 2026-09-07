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
  public var callableName: String? = nil
  public var parameters: [String]? = nil
  public var signatureWithoutParameters: String? = nil
  // Exact token sequences are retained only in memory; they are not sent to reviewers.
  var bodyTokens: [String]? = nil
  var initializerTokens: [String]? = nil
  var endLine: Int? = nil
  enum CodingKeys: String, CodingKey {
    case key, kind, signature, location, body, forwardingCall
    case callableName, parameters, signatureWithoutParameters
  }
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
  // Internal syntax identity for presentation; JSON notice contract remains unchanged.
  var conditionalHeader: String? = nil
  enum CodingKeys: String, CodingKey { case location, message }
}

public struct Snapshot: Encodable, Sendable {
  public let schemaVersion = 2
  public let analysis = "syntax-only"
  public var files = 0
  public var types: [TypeRecord] = []
  public var notices: [Notice] = []
  var sourceByPath: [String: String] = [:]
  var tokensByPath: [String: [String]] = [:]
  enum CodingKeys: String, CodingKey {
    case schemaVersion, analysis, files, types, notices, limitations
  }
  public let limitations = [
    "Type spellings are not resolved symbols or semantic dependency edges.",
    "Extensions are separate records; identities include file paths. Moves/renames appear as removal/addition.",
    "All conditional-compilation branches are parsed; macros are not expanded.",
    "Inferred types, call targets, module membership, purity and transitive effects are not resolved.",
    "No finding does not imply that the design is safe or unchanged.",
    "Coverage refers to changed analyzed Swift files after exclusions, not all PR files or line coverage.",
    "Body comparison covers selected members and compares token sequences/counts, not correctness. Unlisted syntax remains outside these checks.",
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
  public var typeID: String = ""
  public var parameterChanges: [ParameterChange] = []
  // Structured source facts supply text grouping; serialized observations retain full edges.
  var textReferenceLines: [String]? = nil
  enum CodingKeys: String, CodingKey {
    case rule, type, location, message, before, after, typeID, parameterChanges
  }
}

public struct ParameterChange: Codable, Sendable {
  public let member: String
  public let beforeSignature: String
  public let afterSignature: String
  public let beforeHeader: String
  public let afterHeader: String
  public let removed: [String]
  public let added: [String]
  public let beforeOrder: [String]
  public let afterOrder: [String]
}

public struct ChangedFile: Codable, Sendable {
  public let file: String
  public let change: String
  public let syntaxChanged: Bool
  public let observationCount: Int
}

public struct BodyComparison: Codable, Sendable {
  public let typeID: String
  public let type: String
  public let member: String
  public let beforeLocation: Location?
  public let afterLocation: Location?
  /// changed-metrics / changed-syntax-only / not-compared
  public let status: String
  public let reason: String
}

public struct ComparisonCoverage: Codable, Sendable {
  public var changedFiles: [ChangedFile] = []
  /// Counts only bodies belonging to changed input files, not the entire repository.
  public var comparedBodyCount = 0
  public var unchangedBodyCount = 0
  public var bodyComparisons: [BodyComparison] = []
  public var skippedBodyCount = 0
}

public struct DiffReport: Encodable, Sendable {
  public let schemaVersion = 2
  public let analysis = "syntax-only"
  public let detail = "full"
  public let beforeLabel: String
  public let afterLabel: String
  public let beforeFiles: Int
  public let afterFiles: Int
  public let findings: [Finding]
  public let notices: [Notice]
  public let limitations: [String]
  public var coverage = ComparisonCoverage()
  public var inventory: ComparisonInventory? = nil
  var textNotices: [String]? = nil
  enum CodingKeys: String, CodingKey {
    case schemaVersion, analysis, detail, beforeLabel, afterLabel, beforeFiles, afterFiles
    case findings, notices, limitations, coverage, inventory
  }
}

public enum SekkaError: Error, CustomStringConvertible {
  case message(String)
  public var description: String {
    switch self {
    case .message(let text): return text
    }
  }
}
