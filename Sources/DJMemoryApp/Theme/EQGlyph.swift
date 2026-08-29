import SwiftUI

/// The brand logomark: a circle enclosing three EQ bars of different heights.
struct EQGlyph: View {
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                Circle().strokeBorder(lineWidth: max(1, s * 0.035))
                HStack(alignment: .center, spacing: s * 0.09) {
                    Capsule().frame(width: s * 0.07, height: s * 0.32)
                    Capsule().frame(width: s * 0.07, height: s * 0.54)
                    Capsule().frame(width: s * 0.07, height: s * 0.21)
                }
            }
            .frame(width: s, height: s)
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}
