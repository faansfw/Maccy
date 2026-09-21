import AppKit
import SwiftUI

/// Contents of an open folder.
struct FolderFlyoutView: View {
  let items: [HistoryItemDecorator]
  let onHover: (Bool) -> Void

  var body: some View {
    MultipleSelectionListView(items: items) { previous, item, next, index in
      HistoryItemView(item: item, previous: previous, next: next, index: index)
    }
    .padding(.vertical, Popup.verticalPadding)
    .padding(.horizontal, Popup.horizontalPadding)
    .frame(maxHeight: .infinity, alignment: .top)
    .background(.regularMaterial)
    .clipShape(.rect(cornerRadius: Popup.cornerRadius + Popup.horizontalPadding))
    .overlay(
      RoundedRectangle(cornerRadius: Popup.cornerRadius + Popup.horizontalPadding)
        .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
    )
    .onHover(perform: onHover)
  }
}

/// A panel that never takes key status, so showing it does not read as focus
/// loss for the popup it hangs off.
private final class FlyoutPanel: NSPanel {
  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }
}

/// Shows the contents of a pinned-items folder in a panel beside the popup.
///
/// The panel is placed outside the popup window, on whichever side has room:
/// to the right by default, flipping to the left when the popup sits near the
/// right edge of the screen.
@MainActor
final class FolderFlyoutPanel {
  static let shared = FolderFlyoutPanel()

  static let width: CGFloat = 260
  private static let gap: CGFloat = 6
  private static let maxHeight: CGFloat = 420

  private var panel: FlyoutPanel?

  private(set) var openFolder: String?

  var isShowing: Bool { panel?.isVisible == true }
  var isKeyWindow: Bool { panel?.isKeyWindow == true }

  /// Opens, or re-renders, the flyout for `folder`.
  /// `rowFrame` is the folder row's frame in the popup window's coordinates.
  func show(
    folder: String,
    items: [HistoryItemDecorator],
    rowFrame: CGRect,
    modifierFlags: ModifierFlags,
    onHover: @escaping (Bool) -> Void
  ) {
    guard let parent = AppState.shared.appDelegate?.panel, !items.isEmpty else {
      hide()
      return
    }

    openFolder = folder

    let height = min(
      Self.maxHeight,
      CGFloat(items.count) * Popup.itemHeight + 2 * Popup.verticalPadding
    )
    let frame = frame(besides: parent, rowFrame: rowFrame, height: height)

    let rootView = FolderFlyoutView(items: items, onHover: onHover)
      .environment(AppState.shared)
      .environment(modifierFlags)

    if let panel {
      panel.contentView = NSHostingView(rootView: rootView)
      panel.setFrame(frame, display: true)
      return
    }

    let panel = FlyoutPanel(
      contentRect: frame,
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    panel.isFloatingPanel = true
    panel.level = parent.level
    panel.hidesOnDeactivate = false
    panel.backgroundColor = .clear
    panel.isOpaque = false
    panel.hasShadow = true
    panel.animationBehavior = .none
    panel.collectionBehavior = [.auxiliary, .stationary, .moveToActiveSpace, .fullScreenAuxiliary]
    panel.contentView = NSHostingView(rootView: rootView)

    parent.addChildWindow(panel, ordered: .above)
    panel.setFrame(frame, display: true)
    panel.orderFront(nil)

    self.panel = panel
  }

  func hide() {
    openFolder = nil

    guard let panel else { return }

    panel.parent?.removeChildWindow(panel)
    panel.orderOut(nil)
    self.panel = nil
  }

  /// Right of the popup when it fits, otherwise left of it, always clamped to
  /// the visible area of the screen the popup is on.
  private func frame(besides parent: NSWindow, rowFrame: CGRect, height: CGFloat) -> NSRect {
    let visible = (parent.screen ?? NSScreen.forPopup ?? NSScreen.main)?.visibleFrame
      ?? parent.frame

    var origin = CGPoint(x: parent.frame.maxX + Self.gap, y: 0)
    if origin.x + Self.width > visible.maxX {
      origin.x = parent.frame.minX - Self.gap - Self.width
    }
    origin.x = min(max(origin.x, visible.minX), max(visible.minX, visible.maxX - Self.width))

    // SwiftUI reports the row top-down, screen coordinates go bottom-up.
    origin.y = parent.frame.maxY - rowFrame.minY - height
    origin.y = min(max(origin.y, visible.minY), max(visible.minY, visible.maxY - height))

    return NSRect(origin: origin, size: CGSize(width: Self.width, height: height))
  }
}
