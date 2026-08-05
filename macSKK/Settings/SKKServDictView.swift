// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import Network

struct SKKServDictView: View {
    @StateObject var settingsViewModel: SettingsViewModel
    @Binding var isShowSheet: Bool
    @State var setting: SKKServDictSetting
    @State var autoDisableThreshold: Int
    @State var information: String = ""
    @State var testing: Bool = false
    @State var yomi: String = ""

    var body: some View {
        VStack {
            Form {
                Section {
                    TextField("Address", text: $setting.address)
                    TextField("TCP Port", value: $setting.port,
                              format: .number.grouping(.never), prompt: Text("1178"))
                    Picker("Request Encoding", selection: $setting.requestEncoding) {
                        ForEach(AllowedEncoding.allCases, id: \.encoding) { allowedEncoding in
                            Text(allowedEncoding.description).tag(allowedEncoding.encoding)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    Picker("Response Encoding", selection: $setting.responseEncoding) {
                        ForEach(AllowedEncoding.allCases, id: \.encoding) { allowedEncoding in
                            Text(allowedEncoding.description).tag(allowedEncoding.encoding)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    Toggle(isOn: $setting.saveToUserDict) {
                        Text("Save conversion history to User Dictionary")
                    }
                    .toggleStyle(.switch)
                    Toggle(isOn: $setting.enableCompletion) {
                        Text("Search completions")
                    }
                    .toggleStyle(.switch)
                    TextField("SKKServAutoDisableThreshold",
                              value: $autoDisableThreshold,
                              format: .number)
                } header: {
                    Text("SKKServDictTitle")
                }
                Section {
                    TextField("Yomi", text: $yomi)
                    HStack {
                        Spacer()
                        Button {
                            runTest { service, destination in
                                try service.completion(yomi: yomi, destination: destination, timeout: 1.0)
                            }
                        } label: {
                            Text("Find Completions")
                        }.disabled(yomi.isEmpty || testing)
                        Button {
                            runTest { service, destination in
                                try service.refer(yomi: yomi, destination: destination, timeout: 1.0)
                            }
                        } label: {
                            Text("Find Candidates")
                        }.disabled(yomi.isEmpty || testing)
                    }
                } header: {
                    Text("SKKServDictReferTestTitle")
                } footer: {
                    if testing {
                        ProgressView().controlSize(.small)
                    }
                    Text(information)
                }
            }
            .formStyle(.grouped)
            Divider()
            HStack {
                Button {
                    information = String(localized: "SKKServDictTesting")
                    runTest(onSuccess: { _ in String(localized: "SKKServClientConnected") }) { service, destination in
                        try service.serverVersion(destination: destination)
                    }
                } label: {
                    Text("Connection Test")
                        .padding([.leading, .trailing])
                }
                .disabled(testing)
                Spacer()
                Button {
                    isShowSheet = false
                } label: {
                    Text("Cancel")
                }
                .keyboardShortcut(.cancelAction)
                Button {
                    var newSetting = setting
                    // enabledはこの画面では編集しない
                    newSetting.enabled = settingsViewModel.skkservDictSetting.enabled
                    settingsViewModel.skkservDictSetting = newSetting
                    settingsViewModel.skkservAutoDisableThreshold = autoDisableThreshold
                    isShowSheet = false
                } label: {
                    Text("Done")
                        .padding([.leading, .trailing])
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            Spacer()
        }
        .frame(width: 480, height: 450)
        .onAppear {
            setting = settingsViewModel.skkservDictSetting
            autoDisableThreshold = settingsViewModel.skkservAutoDisableThreshold
        }
    }

    /**
     * 使い捨ての ``SKKServService`` でテスト用の問い合わせを1回行い、結果を `information` へ反映する。
     *
     * サービスの生成と後始末、`testing` フラグの上げ下げをここにまとめる。
     * `onSuccess` は応答から表示文字列を作るクロージャ。既定では応答をそのまま表示する。
     */
    private func runTest(onSuccess: (String) -> String = { $0 },
                         _ body: (SKKServService, SKKServDestination) throws -> String) {
        let service = SKKServService()
        let destination = SKKServDestination(host: setting.address,
                                             port: setting.port,
                                             requestEncoding: setting.requestEncoding,
                                             responseEncoding: setting.responseEncoding)
        testing = true
        do {
            let response = try body(service, destination)
            logger.log("skkservの応答: \(response, privacy: .public)")
            information = onSuccess(response)
        } catch {
            showError(error)
        }
        // 使い捨てのサービスなのでTCP接続とXPC接続を残さず後始末する
        service.invalidate()
        testing = false
    }

    private func showError(_ error: any Error) {
        if let error = error as? SKKServClientError {
            switch error {
            case .unexpected:
                logger.error("SKKServClientへのXPC呼び出しで不明なエラーが発生しました")
                information = String(localized: "SKKServClientUnknownError")
            case .connectionRefused:
                logger.info("skkservへの通信ができませんでした")
                information = String(localized: "SKKServClientConnectionRefused")
            case .connectionTimeout:
                logger.info("skkservへの接続がタイムアウトしました")
                information = String(localized: "SKKServClientConnectionTimeout")
            case .timeout:
                logger.info("skkservへの通信がタイムアウトしました")
                information = String(localized: "SKKServClientTimeout")
            default:
                logger.error("SKKServClientへのXPC呼び出しで不明なエラーが発生しました")
                information = String(localized: "SKKServClientUnknownError")
            }
        } else {
            logger.error("SKKServClientへのXPC呼び出しで不明なエラーが発生しました")
            information = String(localized: "SKKServClientUnknownError")
        }
    }
}

#Preview {
    let setting = SKKServDictSetting(
        enabled: true,
        address: "127.0.0.1",
        port: 1178,
        requestEncoding: .japaneseEUC,
        responseEncoding: .japaneseEUC,
        saveToUserDict: true,
        enableCompletion: false)
    return SKKServDictView(settingsViewModel: try! SettingsViewModel(skkservDictSetting: setting),
                    isShowSheet: .constant(true),
                    setting: setting,
                    autoDisableThreshold: 3,
                    information: "skkservが応答していません")
}
