// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct DictionaryView: View {
    @Binding var dictSetting: DictSetting?
    let filename: String
    @State var encoding: String.Encoding
    @State var saveToUserDict: Bool

    var body: some View {
        VStack {
            Form {
                Section("Dictionary Setting") {
                    LabeledContent("Filename") {
                        Text(filename)
                    }
                    Picker("Encoding", selection: $encoding) {
                        ForEach(AllowedEncoding.allCases, id: \.encoding) { allowedEncoding in
                            Text(allowedEncoding.description).tag(allowedEncoding.encoding)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .disabled(
                        dictSetting?.type == .json
                    )
                    Toggle(isOn: $saveToUserDict) {
                        Text("Save conversion history to User Dictionary")
                    }
                }
            }
            .formStyle(.grouped)
            Divider()
            HStack {
                Spacer()
                Button {
                    if let dictSetting {
                        if case .traditional = dictSetting.type {
                            dictSetting.type = .traditional(encoding)
                        }
                        dictSetting.saveToUserDict = saveToUserDict
                    }
                    // このビューを閉じる
                    dictSetting = nil
                } label: {
                    Text("Done")
                        .padding([.leading, .trailing])
                }
                .keyboardShortcut(.defaultAction)
                .padding([.trailing, .bottom, .top])
            }
            Spacer()
        }
        .frame(width: 480, height: 270)
    }
}

struct DictionaryView_Previews: PreviewProvider {
    static var previews: some View {
        DictionaryView(
            dictSetting: .constant(nil),
            filename: "SKK-JISYO.sample.utf-8",
            encoding: .utf8,
            saveToUserDict: false,
        ).previewDisplayName("SKK-JISYO.sample.utf-8")
        DictionaryView(
            dictSetting: .constant(nil),
            filename: "SKK-JISYO.L",
            encoding: .japaneseEUC,
            saveToUserDict: true,
        ).previewDisplayName("SKK-JISYO.L")
    }
}
