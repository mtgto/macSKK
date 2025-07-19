// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct DictionaryView: View {
    @StateObject var settingsViewModel: SettingsViewModel
    let filename: String
    let canChangeEncoding: Bool
    @State var encoding: String.Encoding
    @State var saveToUserDict: Bool
    @Environment(\.dismiss) private var dismiss

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
                    .disabled(!canChangeEncoding)
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
                    if let index = settingsViewModel.dictSettings.firstIndex(where: { $0.id == filename }) {
                        let dictSetting = settingsViewModel.dictSettings[index]
                        if case .traditional = dictSetting.type {
                            dictSetting.type = .traditional(encoding)
                        }
                        dictSetting.saveToUserDict = saveToUserDict
                        settingsViewModel.dictSettings[index] = dictSetting
                    }
                    dismiss()
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
            settingsViewModel: try! SettingsViewModel(),
            filename: "SKK-JISYO.sample.json",
            canChangeEncoding: false,
            encoding: .utf8,
            saveToUserDict: false,
        ).previewDisplayName("SKK-JISYO.sample.utf-8")
        DictionaryView(
            settingsViewModel: try! SettingsViewModel(),
            filename: "SKK-JISYO.L",
            canChangeEncoding: true,
            encoding: .japaneseEUC,
            saveToUserDict: true,
        ).previewDisplayName("SKK-JISYO.L")
    }
}
