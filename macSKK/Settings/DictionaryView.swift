// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct DictionaryView: View {
    @Binding var dictSetting: DictSetting?
    let filename: String
    @State var encoding: String.Encoding

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
                        // SKK-JISYO.Lは特定の文字コードでmacSKKに同梱される。（Makefileでビルド時にダウンロードしている）
                        // ユーザーがこれをnkfなどでUTF-8に変更したとしても、macSKKのバージョンをアップデートするたびに
                        // 上書きされて文字コードが異なって読み込みエラーとなる可能性がある。
                        // 従ってファイル名が`SKK-JISYO.L`な場合は文字コードの変更を禁止する。
                        // （文字コードを変更したい場合は、SKK-JISYO.Lをdisableにして別名で辞書ディレクトリーに設置するべきと思われる）
                        filename == "SKK-JISYO.L"
                    )
                    if filename == "SKK-JISYO.L" {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                            Text("Unable to change encoding SKK-JISYO.L")
                        }
                    }
                }
            }
            .formStyle(.grouped)
            Divider()
            HStack {
                Spacer()
                Button {
                    dictSetting?.encoding = encoding
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
            encoding: .utf8
        ).previewDisplayName("SKK-JISYO.sample.utf-8")        
        DictionaryView(
            dictSetting: .constant(nil),
            filename: "SKK-JISYO.L",
            encoding: .japaneseEUC
        ).previewDisplayName("SKK-JISYO.L")
    }
}
