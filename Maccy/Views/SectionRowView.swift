import SwiftUI

/// A non-selectable, clickable row. Used for the collapsed tail of the history.
struct SectionRowView: View {
  var title: LocalizedStringKey
  var count: Int?
  var isExpanded: Bool
  var action: () -> Void

  @State private var isHovered: Bool = false

  var body: some View {
    HStack(spacing: 5) {
      Image(systemName: "chevron.right")
        .font(.system(size: 9, weight: .semibold))
        .rotationEffect(.degrees(isExpanded ? 90 : 0))
        .foregroundStyle(.secondary)
        .frame(width: 10)

      Text(title, tableName: "PinsSettings")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .lineLimit(1)

      if let count {
        Text(verbatim: "\(count)")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .padding(.horizontal, 5)
          .padding(.vertical, 1)
          .background(Color.secondary.opacity(0.15), in: Capsule())
      }

      Spacer(minLength: 0)
    }
    .padding(.horizontal, 10)
    .frame(minHeight: Popup.itemHeight)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      isHovered ? Color.secondary.opacity(0.15) : Color.white.opacity(0.001),
      in: .rect(cornerRadius: Popup.cornerRadius)
    )
    .onHover { isHovered = $0 }
    .onTapGesture(perform: action)
    .accessibilityIdentifier("section-row")
  }
}
