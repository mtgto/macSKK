// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// 変換候補の選択に使うキーを自由に入力するシート
struct SelectCandidateKeysView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var settingsViewModel: SettingsViewModel
    @State var keys: String

    var body: some View {
        let result = Result { () throws(SelectCandidateKeys.ValidationError) -> String in
            try SelectCandidateKeys.validate(keys)
        }
        VStack {
            Form {
                Section {
                    TextField("Keys", text: $keys, prompt: Text(SelectCandidateKeys.default))
                        .font(.body.monospaced())
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SelectCandidateKeysDescription")
                            .foregroundStyle(.secondary)
                        // エラーの有無でシートの高さが変わらないよう、エラーがないときも2行分の領域を確保して隠す
                        let errorMessage: String? = if case .failure(let error) = result { Self.message(for: error) } else { nil }
                        Label {
                            Text(errorMessage ?? " ")
                                .lineLimit(2, reservesSpace: true)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                        }
                        .foregroundStyle(.red)
                        .opacity(errorMessage == nil ? 0 : 1)
                        .accessibilityHidden(errorMessage == nil)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                Button {
                    if case .success(let validated) = result {
                        settingsViewModel.selectCandidateKeys = validated
                    }
                    dismiss()
                } label: {
                    Text("Done")
                        .padding([.leading, .trailing])
                }
                .keyboardShortcut(.defaultAction)
                .disabled((try? result.get()) == nil)
            }
            // 上はFormの下余白があるので詰める
            .padding([.horizontal, .bottom])
        }
        .frame(width: 420)
    }

    private static func message(for error: SelectCandidateKeys.ValidationError) -> String {
        switch error {
        case .invalidLength(let count):
            return String(localized: "SelectCandidateKeysErrorLength \(SelectCandidateKeys.count) \(count)")
        case .duplicated(let characters):
            return String(localized: "SelectCandidateKeysErrorDuplicated \(Self.quoted(characters))")
        case .invalidCharacters(let characters):
            return String(localized: "SelectCandidateKeysErrorInvalidCharacters \(Self.quoted(characters))")
        }
    }

    /// エラーメッセージ中で文字を示すために "A", "B" のように引用符で囲んで並べる
    private static func quoted(_ characters: [Character]) -> String {
        characters.map { character in
            switch character {
            case " ": "\"␣\""
            case "\t": "\"⇥\""
            default: "\"\(character)\""
            }
        }.joined(separator: ", ")
    }
}

#Preview {
    SelectCandidateKeysView(settingsViewModel: try! SettingsViewModel(), keys: "ASDFGHJKL")
}

#Preview("Error") {
    SelectCandidateKeysView(settingsViewModel: try! SettingsViewModel(), keys: "AASDF")
}
