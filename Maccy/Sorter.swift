import AppKit
import Defaults

// swiftlint:disable identifier_name
// swiftlint:disable type_name
class Sorter {
  enum By: String, CaseIterable, Identifiable, CustomStringConvertible, Defaults.Serializable {
    case lastCopiedAt
    case firstCopiedAt
    case numberOfCopies

    var id: Self { self }

    var description: String {
      switch self {
      case .lastCopiedAt:
        return NSLocalizedString("LastCopiedAt", tableName: "StorageSettings", comment: "")
      case .firstCopiedAt:
        return NSLocalizedString("FirstCopiedAt", tableName: "StorageSettings", comment: "")
      case .numberOfCopies:
        return NSLocalizedString("NumberOfCopies", tableName: "StorageSettings", comment: "")
      }
    }
  }

  func sort(_ items: [HistoryItem], by: By = Defaults[.sortBy]) -> [HistoryItem] {
    let pinned = items
      .enumerated()
      .filter { $0.element.pin != nil }
      // Index breaks ties so equal orders keep their relative position.
      .sorted { ($0.element.order, $0.offset) < ($1.element.order, $1.offset) }
      .map(\.element)

    let unpinned = items
      .filter { $0.pin == nil }
      .sorted { bySortingAlgorithm($0, $1, by) }

    return Defaults[.pinTo] == .bottom ? unpinned + pinned : pinned + unpinned
  }

  /// Order to give a newly pinned item so that it lands at the end.
  func nextPinOrder(in items: [HistoryItem]) -> Int {
    (items.filter { $0.pin != nil }.map(\.order).max() ?? 0) + 1
  }

  private func bySortingAlgorithm(_ lhs: HistoryItem, _ rhs: HistoryItem, _ by: By) -> Bool {
    switch by {
    case .firstCopiedAt:
      return lhs.firstCopiedAt > rhs.firstCopiedAt
    case .numberOfCopies:
      return lhs.numberOfCopies > rhs.numberOfCopies
    default:
      return lhs.lastCopiedAt > rhs.lastCopiedAt
    }
  }

}
// swiftlint:enable identifier_name
// swiftlint:enable type_name
