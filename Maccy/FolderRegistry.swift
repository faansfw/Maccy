import Defaults
import Foundation

/// One folder worth of pinned items, ready to be fed to `ForEach(id: \.name)`.
struct FolderSection<Item> {
  let name: String
  let items: [Item]
}

/// Folders group pinned items. Membership is stored on the item itself
/// (`HistoryItem.folderName`), while the ordered folder list lives in
/// user defaults.
enum FolderRegistry {
  static var folders: [String] {
    Defaults[.pinFolders]
  }

  /// Appends a folder unless one with the same name already exists.
  static func add(_ name: String) {
    let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty, !Defaults[.pinFolders].contains(name) else { return }

    Defaults[.pinFolders].append(name)
  }

  /// Builds a name that does not clash with the existing ones, e.g. "Folder 2".
  static func uniqueName(basedOn base: String) -> String {
    let folders = Set(Defaults[.pinFolders])
    guard folders.contains(base) else { return base }

    var index = 2
    while folders.contains("\(base) \(index)") {
      index += 1
    }

    return "\(base) \(index)"
  }

  static func remove(_ name: String) {
    Defaults[.pinFolders].removeAll { $0 == name }
  }

  static func rename(_ name: String, to newName: String) {
    let newName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !newName.isEmpty, name != newName else { return }

    Defaults[.pinFolders] = Defaults[.pinFolders].map { $0 == name ? newName : $0 }
  }

  static func move(_ name: String, by offset: Int) {
    var folders = Defaults[.pinFolders]
    guard let index = folders.firstIndex(of: name) else { return }

    let newIndex = index + offset
    guard folders.indices.contains(newIndex) else { return }

    folders.swapAt(index, newIndex)
    Defaults[.pinFolders] = folders
  }

  /// Splits items into the ones shown directly in the popup and the folder
  /// sections shown underneath. Empty folders are omitted, and folders keep
  /// their configured order.
  static func group<Item>(
    _ items: [Item],
    folderOf: (Item) -> String?
  ) -> (loose: [Item], folders: [FolderSection<Item>]) {
    let known = folders
    var buckets: [String: [Item]] = [:]
    var loose: [Item] = []

    for item in items {
      if let folder = folderOf(item), known.contains(folder) {
        buckets[folder, default: []].append(item)
      } else {
        loose.append(item)
      }
    }

    let sections = known.compactMap { name -> FolderSection<Item>? in
      guard let items = buckets[name], !items.isEmpty else { return nil }
      return FolderSection(name: name, items: items)
    }

    return (loose: loose, folders: sections)
  }
}
