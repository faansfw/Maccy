import Defaults
import SwiftUI

/// A folder entry in the pinned area. Its contents open in a panel beside the
/// popup rather than expanding the list downwards.
private struct FolderRowView: View {
  let name: String
  let count: Int
  let isOpen: Bool
  let onFrameChange: (CGRect) -> Void
  let onHover: (Bool) -> Void
  let onTap: () -> Void

  var body: some View {
    HStack(spacing: 5) {
      Image(systemName: isOpen ? "folder.fill" : "folder")
        .font(.system(size: 10))
        .foregroundStyle(isOpen ? Color.white : .secondary)
        .frame(width: 12)

      Text(verbatim: name)
        .lineLimit(1)
        .truncationMode(.middle)
        .foregroundStyle(isOpen ? Color.white : .primary)

      Spacer(minLength: 4)

      Text(verbatim: "\(count)")
        .font(.caption2)
        .foregroundStyle(isOpen ? Color.white : .secondary)

      Image(systemName: "chevron.right")
        .font(.system(size: 9, weight: .semibold))
        .foregroundStyle(isOpen ? Color.white : .secondary)
    }
    .padding(.horizontal, 10)
    .frame(minHeight: Popup.itemHeight)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      isOpen ? Color.accentColor.opacity(0.8) : Color.white.opacity(0.001),
      in: .rect(cornerRadius: Popup.cornerRadius)
    )
    .background(
      GeometryReader { geo in
        Color.clear
          .onChange(of: geo.frame(in: .global), initial: true) { _, frame in
            onFrameChange(frame)
          }
      }
    )
    .onHover(perform: onHover)
    .onTapGesture(perform: onTap)
  }
}

/// Pinned items: the ones outside any folder are listed exactly like stock
/// Maccy, with the folders following underneath.
struct PinsView: View {
  @Environment(AppState.self) private var appState
  @Environment(ModifierFlags.self) private var modifierFlags
  @Environment(\.scenePhase) private var scenePhase

  @Default(.pinFolders) private var folders

  /// Every pinned row, folder members included.
  var items: [HistoryItemDecorator]

  @State private var openFolder: String?
  @State private var rowFrames: [String: CGRect] = [:]
  @State private var rowHovered: String?
  @State private var flyoutHovered: Bool = false
  @State private var hoverTask: Task<Void, Never>?

  private static let hoverOpenDelay: Duration = .milliseconds(180)
  private static let hoverCloseDelay: Duration = .milliseconds(250)

  private var sections: (loose: [HistoryItemDecorator], folders: [FolderSection<HistoryItemDecorator>]) {
    FolderRegistry.group(items, folderOf: \.folderName)
  }

  var body: some View {
    let sections = sections

    VStack(spacing: 0) {
      MultipleSelectionListView(items: sections.loose.filter(\.isVisible)) { previous, item, next, index in
        HistoryItemView(item: item, previous: previous, next: next, index: index)
      }

      ForEach(sections.folders, id: \.name) { folder in
        FolderRowView(
          name: folder.name,
          count: folder.items.count,
          isOpen: openFolder == folder.name,
          onFrameChange: { rowFrames[folder.name] = $0 },
          onHover: { hovering in
            rowHovered = hovering ? folder.name : nil
            scheduleHoverUpdate(for: folder.name, hovering: hovering)
          },
          onTap: {
            hoverTask?.cancel()
            if openFolder == folder.name {
              close()
            } else {
              open(folder.name)
            }
          }
        )
      }
    }
    .onChange(of: scenePhase) {
      if scenePhase != .active { close() }
    }
    .onChange(of: items.map(\.id)) {
      // Keep the open flyout in sync with pins being added, removed or moved.
      guard let openFolder else { return }

      if sections.folders.contains(where: { $0.name == openFolder }) {
        open(openFolder)
      } else {
        close()
      }
    }
    .onDisappear(perform: close)
  }

  private func open(_ folder: String) {
    guard let section = sections.folders.first(where: { $0.name == folder }) else {
      close()
      return
    }

    openFolder = folder
    FolderFlyoutPanel.shared.show(
      folder: folder,
      items: section.items,
      rowFrame: rowFrames[folder] ?? .zero,
      modifierFlags: modifierFlags
    ) { hovering in
      flyoutHovered = hovering
      scheduleHoverUpdate(for: folder, hovering: hovering)
    }
  }

  private func close() {
    hoverTask?.cancel()
    openFolder = nil
    rowHovered = nil
    flyoutHovered = false
    FolderFlyoutPanel.shared.hide()
  }

  /// Opens on hover after a short delay and closes once the pointer has left
  /// both the row and the flyout, so moving between them does not flicker.
  private func scheduleHoverUpdate(for folder: String, hovering: Bool) {
    hoverTask?.cancel()
    hoverTask = Task { @MainActor in
      try? await Task.sleep(for: hovering ? Self.hoverOpenDelay : Self.hoverCloseDelay)
      guard !Task.isCancelled else { return }

      if hovering {
        open(folder)
      } else if rowHovered == nil, !flyoutHovered {
        close()
      }
    }
  }
}
