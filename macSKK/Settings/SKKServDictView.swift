// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import Network

struct SKKServDictView: View {
    @StateObject var settingsViewModel: SettingsViewModel
    @Binding var isShowSheet: Bool
    @State var information: String = ""
    @State var testing: Bool = false

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
                } header: {
                    Text("SKKServDictTitle")
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
                    Task {
                        do {
                            let version = try await skkservService.serverVersion(destination: destination)
                            print("skkservのバージョン: \(version)")
                            information = String(localized: "SKKServClientConnected")
                        } catch {
                            if let error = error as? SKKServClientError {
                                switch error {
                                case .unexpected:
                                    logger.error("SKKServClientへのXPC呼び出しで不明なエラーが発生しました")
                                    information = String(localized: "SKKServClientUnknownError")
                                case .connectionRefused:
                                    logger.info("skkservへの通信ができませんでした")
                                    information = String(localized: "SKKServClientConnectionRefused")
                                case .connectionTimeout:
                                    logger.info("skkservへの通信がタイムアウトしました")
                                    information = String(localized: "SKKServClientConnectionTimeout")
                                default:
                                    logger.error("SKKServClientへのXPC呼び出しで不明なエラーが発生しました")
                                    information = String(localized: "SKKServClientUnknownError")
                                }
                            } else {
                                logger.error("SKKServClientへのXPC呼び出しで不明なエラーが発生しました")
                                information = String(localized: "SKKServClientUnknownError")
                            }
                        }
                        testing = false
                    }
                } label: {
                    Text("Test")
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
        .frame(width: 480, height: 270)
    }
}

#Preview {
    SKKServDictView(settingsViewModel: try! SettingsViewModel(skkservDictSetting: SKKServDictSetting()),
                    isShowSheet: .constant(true), information: "skkservが応答していません")
}
