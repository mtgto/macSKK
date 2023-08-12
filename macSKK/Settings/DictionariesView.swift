// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct DictionariesView: View {
    @ObservedObject var settingsViewModel: SettingsViewModel

    var body: some View {
        // 辞書のファイル名と有効かどうかのトグル + 詳細表示のiボタン
        // 詳細はシートでエンコーディング、エントリ数が見れる
        // エントリ一覧が検索できてもいいかもしれない
        VStack {
            Form {
                ForEach($settingsViewModel.fileDicts) { fileDict in
                    // テキストを二行にして、ファイル名と二行目にエンコーディングとエントリ数/読み込み状態/エラーを出したい
                    Toggle(isOn: fileDict.enabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(fileDict.id)
                                .font(.headline)
                            HStack {
                                Text(loadingStatus(of: fileDict.wrappedValue))
                                    .font(.subheadline)
                            }
                        }
                    }
                    .toggleStyle(.switch)
                    // Switchの右にiボタン置いてシートでエンコーディングを変更できるようにしたい?
                }
            }
            .formStyle(.grouped)
            Spacer()
        }
    }

    private func loadingStatus(of setting: DictSetting) -> String {
        if let status = settingsViewModel.dictLoadingStatuses[setting.id] {
            switch status {
            case .loaded(let count):
                return "\(count)エントリ"
            case .loading:
                return "読み込み中…"
            case .fail(let error):
                return "エラー: \(error.localizedDescription)"
            }
        } else if !setting.enabled {
            return "未使用"
        } else {
            return "不明"
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
