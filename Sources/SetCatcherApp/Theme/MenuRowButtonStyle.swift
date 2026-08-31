import SwiftUI

/// Hover and pressed treatment for compact menu-bar command rows.
internal struct MenuRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        MenuRowHoverBackground(isPressed: configuration.isPressed) {
            configuration.label
        }
    }
}
