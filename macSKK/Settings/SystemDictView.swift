// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

#if DEBUG

import SwiftUI

/// システム辞書で引いてみるデバッグ機能。
struct SystemDictView: View {
    @State private var word: String = ""
    @State private var selectedDict: SystemDict.Kind = SystemDict.Kind.daijirin
    @State private var displayText: String = ""

    var body: some View {
        Form {
            Section(header: Text("見出し")) {
                TextField("", text: $word)
                    .onChange(of: word) { newValue in
                        if newValue.isEmpty {
                            displayText = ""
                        } else if let found = SystemDict.lookup(newValue, for: selectedDict) {
                            displayText = found
                        } else {
                            displayText = "見つかりませんでした"
                        }
                    }
            }
            Section(header: Text("辞書")) {
                Picker("", selection: $selectedDict) {
                    Text("スーパー大辞林").tag(SystemDict.Kind.daijirin)
                    Text("ウィズダム英和・和英").tag(SystemDict.Kind.wisdom)
                }
            }
            Section(header: Text("結果")) {
                TextEditor(text: .constant(displayText))
            }
        }
        .padding()
    }
}

struct SystemDictView_Previews: PreviewProvider {
    static var previews: some View {
        SystemDictView()
    }
}

#endif
