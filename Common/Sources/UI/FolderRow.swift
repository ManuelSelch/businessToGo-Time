import SwiftUI

public struct FolderRow: View {
    let title: String
    let subtitle: String?
    let color: Color
    let showsChevron: Bool
    let minHeight: CGFloat

    public init(title: String, subtitle: String? = nil, color: Color, showsChevron: Bool = true, minHeight: CGFloat = 58) {
        self.title = title
        self.subtitle = subtitle
        self.color = color
        self.showsChevron = showsChevron
        self.minHeight = minHeight
    }

    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder").foregroundStyle(color)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold))
                if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
            }
            Spacer()
            if showsChevron { Image(systemName: "chevron.right").foregroundStyle(.secondary) }
        }
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
        .contentShape(Rectangle())
    }
}
