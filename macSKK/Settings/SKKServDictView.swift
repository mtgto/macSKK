// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import Network

struct SKKServDictView: View {
    @StateObject var settingsViewModel: SettingsViewModel
    @Binding var isShowSheet: Bool
    @State var information: String = ""
    @State var testing: Bool = false
    @State var yomi: String = ""

    var body: some View {
        VStack {
            Form {
                Section {
                    TextField("Address", text: $settingsViewModel.skkservDictSetting.address)
                    TextField("TCP Port", value: $settingsViewModel.skkservDictSetting.port,
                              format: .number.grouping(.never), prompt: Text("1178"))
                    Picker("Response Encoding", selection: $settingsViewModel.skkservDictSetting.encoding) {
                        ForEach(AllowedEncoding.allCases, id: \.encoding) { allowedEncoding in
                            Text(allowedEncoding.description).tag(allowedEncoding.encoding)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    Toggle(isOn: $settingsViewModel.skkservDictSetting.saveToUserDict) {
                        Text("Save conversion history to User Dictionary")
                    }
                    .toggleStyle(.switch)
                } header: {
                    Text("SKKServDictTitle")
                }
                Section {
                    TextField("Yomi", text: $yomi)
                    HStack {
                        Spacer()
                        Button {
                            let skkservService = SKKServService()
                            let setting = settingsViewModel.skkservDictSetting
                            let destination = SKKServDestination(host: setting.address,
                                                                 port: setting.port,
                                                                 encoding: setting.encoding)
                            testing = true
                            let result = Result {
                                try skkservService.completion(yomi: yomi, destination: destination, timeout: 1.0)
                            }
                            switch result {
                            case .success(let response):
                                logger.log("skkservの応答: \(response, privacy: .public)")
                                information = response
                            case .failure(let error):
                                showError(error)
                            }
                            testing = false
                        } label: {
                            Text("Find Completions")
                        }.disabled(yomi.isEmpty || testing)
                        Button {
                            let skkservService = SKKServService()
                            let setting = settingsViewModel.skkservDictSetting
                            let destination = SKKServDestination(host: setting.address,
                                                                 port: setting.port,
                                                                 encoding: setting.encoding)
                            testing = true
                            let result = Result {
                                try skkservService.refer(yomi: yomi, destination: destination, timeout: 1.0)
                            }
                            switch result {
                            case .success(let response):
                                logger.log("skkservの応答: \(response, privacy: .public)")
                                information = response
                            case .failure(let error):
                                showError(error)
                            }
                            testing = false
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
                    let skkservService = SKKServService()
                    let setting = settingsViewModel.skkservDictSetting
                    let destination = SKKServDestination(host: setting.address,
                                                         port: setting.port,
                                                         encoding: setting.encoding)
                    testing = true
                    information = String(localized: "SKKServDictTesting")
                    let result = Result {
                        try skkservService.serverVersion(destination: destination)
                    }
                    switch result {
                    case .success(let version):
                        logger.log("skkservのバージョン: \(version, privacy: .public)")
                        information = String(localized: "SKKServClientConnected")
                    case .failure(let error):
                        showError(error)
                    }
                    testing = false
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
        .frame(width: 480, height: 400)
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
        encoding: .japaneseEUC,
        saveToUserDict: true)
    return SKKServDictView(settingsViewModel: try! SettingsViewModel(skkservDictSetting: setting),
                    isShowSheet: .constant(true), information: "skkservが応答していません")
}
