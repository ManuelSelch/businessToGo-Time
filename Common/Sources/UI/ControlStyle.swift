import SwiftUI

/// Shared dimensions for compact native controls and their touch targets.
public enum ControlSpacing {
    public static let touchTarget: CGFloat = 44
    public static let iconSize: CGFloat = 17
    public static let compact: CGFloat = 8
    public static let standard: CGFloat = 16
}

public struct IconButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: ControlSpacing.iconSize, weight: .medium))
            .frame(minWidth: ControlSpacing.touchTarget, minHeight: ControlSpacing.touchTarget)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}
