// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct DirectModeView: View {
    @Binding var bundleIdentifiers: [String]

    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
    }
}

struct DirectModeView_Previews: PreviewProvider {
    static var previews: some View {
        DirectModeView(bundleIdentifiers: .constant(["net.mtgto.inputmethod.macSKK"]))
    }
}
