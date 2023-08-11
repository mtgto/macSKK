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
            ForEach($settingsViewModel.dictSettings, id: \.self) { dictSetting in
                //Toggle("SKK-JISYO.L", isOn: dictSetting.enabled)
                Text("SKK-JISYO.L")
            }
        }
    }
}

struct DictionariesView_Previews: PreviewProvider {
    static var previews: some View {
        DictionariesView(settingsViewModel: SettingsViewModel())
    }
}
