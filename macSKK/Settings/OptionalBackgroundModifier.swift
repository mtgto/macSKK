// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct OptionalBackgroundModifier: ViewModifier {
    let color: Color?
    let cornerRadius: CGFloat?

    func body(content: Content) -> some View {
        if let color {
            if let cornerRadius {
                content.background(color, in: RoundedRectangle(cornerRadius: cornerRadius))
            } else {
                content.background(color)
            }
        } else {
            if let cornerRadius {
                content.background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
            } else {
                content
            }
        }
    }
}

extension View {
    func optionalBackground(_ color: Color?) -> some View {
        self.modifier(OptionalBackgroundModifier(color: color, cornerRadius: nil))
    }

    func optionalBackground(_ color: Color?, cornerRadius: CGFloat) -> some View {
        self.modifier(OptionalBackgroundModifier(color: color, cornerRadius: cornerRadius))
    }
}
