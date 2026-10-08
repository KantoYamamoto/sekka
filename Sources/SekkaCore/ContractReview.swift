import CallbackContracts
import Foundation

/// An opt-in trial, separate from the structural diff report and its observation count.
public struct ContractReviewReport: Encodable {
  public let schemaVersion = 1
  public let analysis = "experimental-callback-contracts"
  public let beforeLabel: String
  public let afterLabel: String
  public let inventory: ComparisonInventory
  public let contract: CallbackContracts.Report
  public var hasCandidates: Bool { !contract.changes.isEmpty }
}

public enum ContractReview {
  public static func compare(
    before: [(path: String, source: String)], after: [(path: String, source: String)],
    beforeLabel: String, afterLabel: String, inventory: ComparisonInventory
  ) throws -> ContractReviewReport {
    let old = try SourceInventory(before), new = try SourceInventory(after)
    return ContractReviewReport(beforeLabel: beforeLabel, afterLabel: afterLabel, inventory: inventory.includingSourceChanges(before: before, after: after),
      contract: CallbackContracts.compare(old, new))
  }

  public static func text(_ report: ContractReviewReport) -> String {
    "Sekka · experimental API boundary review\n" + report.beforeLabel + " → " + report.afterLabel
      + "\nChanged paths: \(report.inventory.changes.count); scope: \(report.inventory.scope)\n"
      + "Trial covers one callback contract shape; zero is not design approval. Use the ordinary diff.\n\n"
      + CallbackContracts.render(report.contract)
  }

  public static func json(_ report: ContractReviewReport) throws -> String {
    let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    return String(decoding: try encoder.encode(report), as: UTF8.self)
  }
}
