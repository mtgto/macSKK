// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct OptionalBackgroundModifier: ViewModifier {
    let color: Color?

    func body(content: Content) -> some View {
        if let color {
            content.background(color)
        } else {
            content
        }
    }
}

extension View {
    func optionalBackground(_ color: Color?) -> some View {
        self.modifier(OptionalBackgroundModifier(color: color))
    }
}
