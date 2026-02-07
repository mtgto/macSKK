// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct KanaRuleView: View {
    @StateObject var settingsViewModel: SettingsViewModel

    var body: some View {
        VStack {
            Form {
                Section {
                    Picker("Kana Rule", selection: $settingsViewModel.selectedKanaRule) {
                        Text("Default").tag("")
                        if !settingsViewModel.kanaRules.isEmpty {
                            Divider()
                        }
                        ForEach($settingsViewModel.kanaRules) { kanaRule in
                            Text(kanaRule.id).tag(kanaRule.id)
                        }
                    }
                } footer: {
                    Button {
                        do {
                            let settingsDirectoryURL = try FileManager.default.url(
                                for: .documentDirectory,
                                in: .userDomainMask,
                                appropriateFor: nil,
                                create: false
                            ).appending(path: "Settings")
                            NSWorkspace.shared.open(settingsDirectoryURL)
                        } catch {
                            logger.error("設定フォルダが開けませんでした: \(error)")
                        }
                    } label: {
                        Text("Show Settings in Finder")
                    }
                    Button {
                        if let kanaRuleURL = Bundle.main.url(forResource: "kana-rule", withExtension: "conf") {
                            NSWorkspace.shared.activateFileViewerSelecting([kanaRuleURL])
                        }

                    } label: {
                        Text("Show Default rule file in Finder")
                    }
                }
            }
            .formStyle(.grouped)
            Text("SettingsNoteKanaRule")
                .font(.subheadline)
                .padding([.bottom, .leading, .trailing])
            Spacer()
        }
    }
}

#Preview {
    KanaRuleView(settingsViewModel: try! SettingsViewModel())
}
