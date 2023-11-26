// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct GeneralView: View {
    @State var selection: String?

    var body: some View {
        VStack {
            Form {
                Section {
                    Picker("キー配列", selection: $selection) {

                    }
                } header: {
                    Text("キー配列")
                }
                Button("キー配列取得") {
                    let ary = InputSource.fetch()
                    print(ary)
                }
            }
            .formStyle(.grouped)
        }
    }
}

#Preview {
    GeneralView()
}
