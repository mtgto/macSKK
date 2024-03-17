// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import Network

struct SKKServDictView: View {
    @StateObject var settingsViewModel: SettingsViewModel
    @Binding var isShowSheet: Bool

    var body: some View {
        VStack {
            Form {
                Section("SKKServ Dictionary Setting") {
                    TextField("Address", text: $settingsViewModel.skkservDictSetting.address)
                    TextField("Port", value: $settingsViewModel.skkservDictSetting.port, format: .number, prompt: Text("1178"))
                    Picker("Response Encoding", selection: $settingsViewModel.skkservDictSetting.encoding) {
                        ForEach(AllowedEncoding.allCases, id: \.encoding) { allowedEncoding in
                            Text(allowedEncoding.description).tag(allowedEncoding.encoding)
                        }
                    }
                    .pickerStyle(.radioGroup)
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
                    Task {
                        do {
                            let version = try await skkservService.serverVersion(destination: destination)
                            print("skkservのバージョン: \(version)")
                        } catch {
                            print("skkservの通信でエラーが発生しました: \(error)")
                        }
                    }
                } label: {
                    Text("Test")
                        .padding([.leading, .trailing])
                }
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
                    isShowSheet: .constant(true))
}
