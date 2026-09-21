import Defaults
import SwiftData
import SwiftUI

struct PinTitleView: View {
  @Bindable var item: HistoryItem

  var body: some View {
    TextField("", text: $item.title)
  }
}

struct PinValueView: View {
  @Bindable var item: HistoryItem
  @State private var editableValue: String
  @State private var isTextContent: Bool
  @State private var isRichText: Bool
  @FocusState private var isEditing: Bool
  @State private var showWarningPopover: Bool = false

  init(item: HistoryItem) {
    self.item = item
    self._editableValue = State(initialValue: item.previewableText)

    // Check if this item has editable text content
    let hasPlainText = item.text != nil
    let hasImage = item.image != nil
    let hasFileURLs = !item.fileURLs.isEmpty
    let hasRichText = item.rtf != nil || item.html != nil

    // Consider it text content only if it has plain text and doesn't have images or file URLs
    self._isTextContent = State(initialValue: hasPlainText && !hasImage && !hasFileURLs)
    self._isRichText = State(initialValue: hasRichText && !hasImage && !hasFileURLs)
  }

  var body: some View {
    Group {
      if isTextContent || isRichText {
        ZStack(alignment: .trailing) {
          TextField("", text: $editableValue)
            .focused($isEditing)
            .onSubmit {
              updateItemContent()
            }
            .onChange(of: editableValue) { _, _ in
              updateItemContent()
            }
            .padding(.trailing, isRichText ? 40 : 0) // increased space for icon

          if isRichText && isEditing {
            HStack(spacing: 0) {
              Spacer(minLength: 0)
              Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .help(Text("RichTextEditWarning", tableName: "PinsSettings"))
              Spacer().frame(width: 4)
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .padding(.trailing, 4)
          }
        }
      } else {
        // Non-editable display for non-text content
        Text("ContentIsNotText", tableName: "PinsSettings")
          .foregroundStyle(.secondary)
          .italic()
      }
    }
  }

  private func updateItemContent() {
    // Only update if we're dealing with text or rich text content
    guard isTextContent || isRichText else { return }

    // Remove all non-plain-text content
    let stringType = NSPasteboard.PasteboardType.string.rawValue
    item.contents.removeAll { $0.type != stringType }

    // Update or add the plain text content
    if let index = item.contents.firstIndex(where: { $0.type == stringType }) {
      if let data = editableValue.data(using: .utf8) {
        item.contents[index].value = data
      }
    } else {
      if let data = editableValue.data(using: .utf8) {
        let newContent = HistoryItemContent(type: stringType, value: data)
        item.contents.append(newContent)
      }
    }
    // We don't automatically update title here since we want to preserve
    // OCR-extracted titles for images and other non-text content
  }
}

/// One pinned item inside the hierarchical list.
private struct PinRowView: View {
  @Bindable var item: HistoryItem
  let folders: [String]

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: "line.3.horizontal")
        .foregroundStyle(.tertiary)
        .font(.caption)

      PinTitleView(item: item)
        .frame(minWidth: 120, idealWidth: 150)

      PinValueView(item: item)
        .frame(maxWidth: .infinity)

      FolderPickerView(
        folders: folders,
        folderName: Binding(
          get: { item.folderName },
          set: { item.folderName = $0 }
        ),
        onChange: { AppState.shared.history.persistAndRefresh() }
      )
      .frame(width: 130)
    }
  }
}

struct PinsSettingsPane: View {
  @Environment(AppState.self) private var appState
  @Environment(\.modelContext) private var modelContext

  @Query(filter: #Predicate<HistoryItem> { $0.pin != nil }, sort: \.order)
  private var items: [HistoryItem]

  @Default(.pinFolders) private var folders

  @State private var selection: PersistentIdentifier?

  private var sections: (loose: [HistoryItem], folders: [FolderSection<HistoryItem>]) {
    FolderRegistry.group(items, folderOf: \.folderName)
  }

  /// The items that live alongside the selected one, i.e. its own section.
  private var selectedSiblings: [HistoryItem] {
    let sections = sections
    if sections.loose.contains(where: { $0.persistentModelID == selection }) {
      return sections.loose
    }

    return sections.folders
      .first { $0.items.contains { $0.persistentModelID == selection } }?
      .items ?? []
  }

  private var selectedIndex: Int? {
    selectedSiblings.firstIndex { $0.persistentModelID == selection }
  }

  var body: some View {
    VStack(alignment: .leading) {
      let sections = sections

      List(selection: $selection) {
        Section {
          ForEach(sections.loose, id: \.persistentModelID) { item in
            PinRowView(item: item, folders: folders)
          }
          .onMove { source, destination in
            move(sections.loose, from: source, to: destination)
          }
        } header: {
          Text("NoFolderSection", tableName: "PinsSettings")
        }

        ForEach(sections.folders, id: \.name) { folder in
          Section {
            ForEach(folder.items, id: \.persistentModelID) { item in
              PinRowView(item: item, folders: folders)
            }
            .onMove { source, destination in
              move(folder.items, from: source, to: destination)
            }
          } header: {
            Label(folder.name, systemImage: "folder")
          }
        }
      }
      .frame(minHeight: 220)
      .onAppear(perform: normalizeOrder)
      .onDeleteCommand(perform: deleteSelected)

      HStack(spacing: 6) {
        Button { move(by: -1) } label: {
          Image(systemName: "chevron.up")
        }
        .disabled(selectedIndex == nil || selectedIndex == 0)
        .help(Text("MoveUpTooltip", tableName: "PinsSettings"))

        Button { move(by: 1) } label: {
          Image(systemName: "chevron.down")
        }
        .disabled(selectedIndex == nil || selectedIndex == selectedSiblings.count - 1)
        .help(Text("MoveDownTooltip", tableName: "PinsSettings"))

        Button(action: deleteSelected) {
          Image(systemName: "minus")
        }
        .disabled(selection == nil)
        .help(Text("DeletePinTooltip", tableName: "PinsSettings"))

        Spacer()
      }

      Text("PinCustomizationDescription", tableName: "PinsSettings")
        .foregroundStyle(.gray)
        .controlSize(.small)

      Divider()

      Text("Folders", tableName: "PinsSettings")
        .font(.subheadline)

      FoldersEditorView(folders: $folders) { oldName, newName in
        AppState.shared.history.reassignPinFolder(from: oldName, to: newName)
      }

      Text("FoldersDescription", tableName: "PinsSettings")
        .foregroundStyle(.gray)
        .controlSize(.small)
    }
    .frame(minWidth: 680, minHeight: 560)
    .padding()
  }

  /// Items pinned before this build all carry order 0, so give them their
  /// current positions once to make reordering meaningful.
  private func normalizeOrder() {
    guard items.contains(where: { $0.order == 0 }) else { return }

    for (index, item) in items.enumerated() {
      item.order = index + 1
    }
    AppState.shared.history.persistAndRefresh()
  }

  /// Reorders within one section by redistributing that section's own order
  /// values, so items in other sections keep their positions.
  private func move(_ siblings: [HistoryItem], from source: IndexSet, to destination: Int) {
    var reordered = siblings
    reordered.move(fromOffsets: source, toOffset: destination)

    for (item, order) in zip(reordered, siblings.map(\.order).sorted()) {
      item.order = order
    }
    AppState.shared.history.persistAndRefresh()
  }

  private func move(by offset: Int) {
    let siblings = selectedSiblings
    guard let index = selectedIndex else { return }

    let newIndex = index + offset
    guard siblings.indices.contains(newIndex) else { return }

    let order = siblings[index].order
    siblings[index].order = siblings[newIndex].order
    siblings[newIndex].order = order
    AppState.shared.history.persistAndRefresh()
  }

  private func deleteSelected() {
    guard let selection,
          let item = appState.history.items.first(where: { $0.item.id == selection }) else {
      return
    }

    self.selection = nil
    appState.history.delete(item)
  }
}

#Preview {
  return PinsSettingsPane()
    .environment(\.locale, .init(identifier: "en"))
    .modelContainer(Storage.shared.container)
}
