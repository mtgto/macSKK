// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct DictionariesView: View {
    @ObservedObject var settingsViewModel: SettingsViewModel

    var body: some View {
        // 辞書のファイル名と有効かどうかのトグル + 詳細表示のiボタン
        // 詳細はシートでエンコーディング、エントリ数が見れる
        // エントリ一覧が検索できてもいいかもしれない
        Form {
            ForEach($settingsViewModel.fileDicts, id: \.self) { fileDict in
                //Toggle(fileDict.id, isOn: settingsViewModel.dictSettings[fileDict])
                Text(fileDict.id)
            }
        }
    }
}

struct DictionariesView_Previews: PreviewProvider {
    static var previews: some View {
        let fileDict = try! FileDict(contentsOf: Bundle.main.url(forResource: "SKK-JISYO.sample", withExtension: "utf-8")!, encoding: .utf8)
        let settings = SettingsViewModel()
        settings.fileDicts = [fileDict]
        return DictionariesView(settingsViewModel: settings)
    }
}
