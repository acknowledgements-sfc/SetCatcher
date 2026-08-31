import SwiftUI

internal struct MenuRowHoverBackground<Label: View>: View {
    let isPressed: Bool
    @ViewBuilder var label: () -> Label
    @State private var hovering = false

    var body: some View {
        label()
            .background(
                (isPressed || hovering) ? DJToken.muted : Color.clear,
                in: RoundedRectangle(cornerRadius: DJToken.Radius.control)
            )
            .onHover { hovering = $0 }
    }
}
