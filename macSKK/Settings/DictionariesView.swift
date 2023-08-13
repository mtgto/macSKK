// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct DictionariesView: View {
    @ObservedObject var settingsViewModel: SettingsViewModel
    @State private var selectedDictSetting: DictSetting?

    var body: some View {
        VStack {
            Form {
                Section {
                    ForEach($settingsViewModel.fileDicts) { fileDict in
                        HStack(alignment: .top) {
                            Toggle(isOn: fileDict.enabled) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(fileDict.id)
                                        .font(.body)
                                    Text(loadingStatus(of: fileDict.wrappedValue))
                                        .font(.footnote)
                                }
                            }
                            .toggleStyle(.switch)
                            Button {
                                selectedDictSetting = fileDict.wrappedValue
                            } label: {
                                Image(systemName: "info.circle")
                                    .resizable()
                                    .frame(width: 16, height: 16)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                } footer: {
                    Button {
                        NSWorkspace.shared.open(settingsViewModel.dictionariesDirectoryUrl)
                    } label: {
                        Text("SettingsOpenDictionaryFolder")
                    }
                    .padding(.top)
                }
            }
            .formStyle(.grouped)
            .sheet(item: $selectedDictSetting) { dictSetting in
                DictionaryView(
                    dictSetting: $selectedDictSetting,
                    filename: dictSetting.filename,
                    encoding: dictSetting.encoding
                )
            }
            Text("SettingsNoteDictionaries")
                .font(.subheadline)
                .padding([.bottom, .leading, .trailing])
            Spacer()
        }
    }

    private func loadingStatus(of setting: DictSetting) -> String {
        if let status = settingsViewModel.dictLoadingStatuses[setting.id] {
            switch status {
            case .loaded(let count):
                return String(format: NSLocalizedString("LoadingStatusLoaded", comment: "%d エントリ"), count)
            case .loading:
                return NSLocalizedString("LoadingStatusLoading", comment: "読み込み中…")
            case .disabled:
                return NSLocalizedString("LoadingStatusDisabled", comment: "無効")
            case .fail(let error):
                return String(format: NSLocalizedString("LoadingStatusError", comment: "エラー: %@"), error as NSError)
            }
        } else if !setting.enabled {
            // 元々無効になっていて、設定を今回の起動で切り替えてない辞書
            return NSLocalizedString("LoadingStatusDisabled", comment: "無効")
        } else {
            return NSLocalizedString("LoadingStatusUnknown", comment: "不明")
        }
    }
}

struct DictionariesView_Previews: PreviewProvider {
    static var previews: some View {
        let dictSettings = [
            DictSetting(filename: "SKK-JISYO.L", enabled: true, encoding: .japaneseEUC),
            DictSetting(filename: "SKK-JISYO.sample.utf-8", enabled: false, encoding: .utf8)
        ]
        let settings = try! SettingsViewModel(dictSettings: dictSettings)
        settings.dictLoadingStatuses = ["SKK-JISYO.L": .loaded(123456), "SKK-JISYO.sample.utf-8": .loading]
        return DictionariesView(settingsViewModel: settings)
    }
}
