// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct DictionaryView: View {
    @Binding var dictSetting: DictSetting?
    @Binding var filename: String
    @Binding var encoding: String.Encoding

    var body: some View {
        VStack {
            Form {
                Section("辞書の設定") {
                    LabeledContent("ファイル名") {
                        Text(filename)
                    }
                    Picker("エンコーディング", selection: $encoding) {
                        ForEach(AllowedEncoding.allCases, id: \.encoding) { allowedEncoding in
                            Text(allowedEncoding.description).tag(allowedEncoding.encoding)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            Divider()
            HStack {
                Button {
                    // TODO: 実装
                } label: {
                    Text("Finderで表示")
                        .padding([.leading, .trailing])
                }
                .padding()
                Spacer()
                Button {
                    dictSetting?.encoding = encoding
                    dictSetting = nil
                } label: {
                    Text("完了")
                        .padding([.leading, .trailing])
                }
                .keyboardShortcut(.defaultAction)
                .padding()
            }
            Spacer()
        }
        .frame(width: 480, height: 270)
    }
}

struct DictionaryView_Previews: PreviewProvider {
    static var previews: some View {
        DictionaryView(dictSetting: .constant(nil), filename: .constant("SKK-JISYO.sample.utf-8"), encoding: .constant(.utf8))
    }
}
