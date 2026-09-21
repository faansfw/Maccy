import Defaults
import SwiftUI

/// Inline rename field that only commits on Enter or when focus is lost,
/// so typing does not rename the folder on every keystroke.
private struct FolderNameField: View {
  let name: String
  let onCommit: (String) -> Void

  @State private var draft: String = ""
  @FocusState private var isFocused: Bool

  var body: some View {
    TextField("", text: $draft)
      .focused($isFocused)
      .onAppear { draft = name }
      .onChange(of: name) { draft = name }
      .onSubmit { commit() }
      .onChange(of: isFocused) {
        if !isFocused { commit() }
      }
  }

  private func commit() {
    let newName = draft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !newName.isEmpty, newName != name else {
      draft = name
      return
    }

    onCommit(newName)
  }
}

/// Folder list editor: create, rename, reorder and delete the folders that
/// group pinned items.
struct FoldersEditorView: View {
  @Binding var folders: [String]
  /// Called with the old name and the new one, or `nil` when deleted, so the
  /// caller can re-assign the items that referenced the folder.
  var onChange: (String, String?) -> Void

  @State private var draft: String = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      if folders.isEmpty {
        Text("NoFolders", tableName: "PinsSettings")
          .foregroundStyle(.gray)
          .controlSize(.small)
      }

      ForEach(folders, id: \.self) { folder in
        HStack(spacing: 4) {
          Image(systemName: "folder")
            .foregroundStyle(.secondary)

          FolderNameField(name: folder) { newName in
            let newName = FolderRegistry.uniqueName(basedOn: newName)
            FolderRegistry.rename(folder, to: newName)
            onChange(folder, newName)
          }

          Button {
            FolderRegistry.move(folder, by: -1)
          } label: {
            Image(systemName: "chevron.up")
          }
          .disabled(folders.first == folder)

          Button {
            FolderRegistry.move(folder, by: 1)
          } label: {
            Image(systemName: "chevron.down")
          }
          .disabled(folders.last == folder)

          Button {
            FolderRegistry.remove(folder)
            onChange(folder, nil)
          } label: {
            Image(systemName: "trash")
          }
        }
        .buttonStyle(.borderless)
      }

      HStack(spacing: 4) {
        TextField(text: $draft) {
          Text("NewFolderName", tableName: "PinsSettings")
        }
        .onSubmit(add)

        Button(action: add) {
          Text("AddFolder", tableName: "PinsSettings")
        }
        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
    }
  }

  private func add() {
    let name = draft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else { return }

    FolderRegistry.add(FolderRegistry.uniqueName(basedOn: name))
    draft = ""
  }
}

/// Picker assigning a pinned item to one of the configured folders.
struct FolderPickerView: View {
  /// Configured folders, passed in so the picker follows the settings pane.
  let folders: [String]
  @Binding var folderName: String?
  var onChange: () -> Void

  private var options: [String] {
    guard let folderName, !folders.contains(folderName) else { return folders }

    // Keep a stale assignment selectable so it is not silently dropped.
    return folders + [folderName]
  }

  var body: some View {
    Picker("", selection: $folderName) {
      Text("NoFolder", tableName: "PinsSettings")
        .tag(String?.none)

      ForEach(options, id: \.self) { folder in
        Text(verbatim: folder)
          .tag(String?.some(folder))
      }
    }
    .controlSize(.small)
    .labelsHidden()
    .onChange(of: folderName) { onChange() }
  }
}
