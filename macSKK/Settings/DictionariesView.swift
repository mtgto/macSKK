// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct DictionariesView: View {
    @ObservedObject var settingsViewModel: SettingsViewModel
    @State private var selectedDictSetting: DictSetting?
    @State var isShowingSkkservSheet: Bool = false

    var body: some View {
        VStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(UserDict.userDictFilename)
                            .font(.body)
                        Text(loadingStatus(of: settingsViewModel.userDictLoadingStatus))
                            .font(.footnote)
                    }
                } header: {
                    Text("SettingsNameUserDictTitle")
                }
                Section {
                    HStack {
                        Toggle(isOn: $settingsViewModel.skkservDictSetting.enabled) {
                            Text("\(settingsViewModel.skkservDictSetting.address):\(String(settingsViewModel.skkservDictSetting.port))")
                                .font(.body)
                        }
                        Button {
                            isShowingSkkservSheet = true
                        } label: {
                            Image(systemName: "info.circle")
                                .resizable()
                                .frame(width: 16, height: 16)
                        }
                        .buttonStyle(.borderless)
                    }
                } header: {
                    Text("SKKServ")
                }
                Section {
                    if settingsViewModel.dictSettings.isEmpty {
                        Text("SettingsFileDictionariesEmpty")
                    } else {
                        List {
                            ForEach($settingsViewModel.dictSettings) { dictSetting in
                                HStack(alignment: .top) {
                                    Toggle(isOn: dictSetting.enabled) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(dictSetting.id)
                                                .font(.body)
                                            Text(loadingStatus(setting: dictSetting.wrappedValue))
                                                .font(.footnote)
                                        }
                                    }
                                    .toggleStyle(.switch)
                                    Button {
                                        selectedDictSetting = dictSetting.wrappedValue
                                    } label: {
                                        Image(systemName: "info.circle")
                                            .resizable()
                                            .frame(width: 16, height: 16)
                                    }
                                    .buttonStyle(.borderless)
                                }
                                .padding(EdgeInsets(top: 4, leading: 2, bottom: 4, trailing: 2))
                            }.onMove { from, to in
                                settingsViewModel.dictSettings.move(fromOffsets: from, toOffset: to)
                            }
                        }
                    }
                } header: {
                    Text("SettingsFileDictionariesTitle")
                    Text("SettingsFileDictionariesSubtitle")
                        .font(.subheadline)
                        .fontWeight(.light)
                } footer: {
                    Button {
                        NSWorkspace.shared.open(settingsViewModel.dictionariesDirectoryUrl)
                    } label: {
                        Text("SettingsOpenDictionaryFolder")
                    }
                    .padding(.top)
                }
            }
            .formStyle(.grouped)
            .sheet(item: $selectedDictSetting) { dictSetting in
                DictionaryView(
                    settingsViewModel: settingsViewModel,
                    filename: dictSetting.filename,
                    canChangeEncoding: dictSetting.type != .json,
                    encoding: dictSetting.type.encoding,
                    saveToUserDict: dictSetting.saveToUserDict,
                )
            }
            .sheet(isPresented: $isShowingSkkservSheet) {
                SKKServDictView(settingsViewModel: settingsViewModel, isShowSheet: $isShowingSkkservSheet)
            }
            Text("SettingsNoteDictionaries")
                .font(.subheadline)
                .padding([.bottom, .leading, .trailing])
            Spacer()
        }
    }

    private func loadingStatus(setting: DictSetting) -> String {
        if !setting.enabled {
            return String(localized: "LoadingStatusDisabled")
        } else if let status = settingsViewModel.dictLoadingStatuses[setting.id] {
            return loadingStatus(of: status)
        } else {
            return String(localized: "LoadingStatusUnknown")
        }
    }

    private func loadingStatus(of status: DictLoadStatus) -> String {
        switch status {
        case .loaded(success: let entryCount, failure: let failureCount):
            if failureCount == 0 {
                return String(localized: "LoadingStatusLoaded \(entryCount)")
            } else {
                return String(localized: "LoadingStatusLoaded \(entryCount) WithError \(failureCount)")
            }
        case .loading:
            return String(localized: "LoadingStatusLoading")
        case .disabled:
            return String(localized: "LoadingStatusDisabled")
        case .fail(let error):
            return String(localized: "LoadingStatusError \(error as NSError)")
        }
    }
}

struct DictionariesView_Previews: PreviewProvider {
    enum DictionariesViewPreviewError: Error {
        case dummy
    }

    private static func makeSettingsViewModel() -> SettingsViewModel {
        let dictSettings = [
            DictSetting(filename: "SKK-JISYO.L", enabled: true, type: .traditional(.japaneseEUC), saveToUserDict: true),
            DictSetting(filename: "SKK-JISYO.sample.utf-8", enabled: false, type: .traditional(.utf8), saveToUserDict: true),
            DictSetting(filename: "SKK-JISYO.dummy", enabled: true, type: .traditional(.utf8), saveToUserDict: true),
            DictSetting(filename: "SKK-JISYO.error", enabled: true, type: .traditional(.utf8), saveToUserDict: true),
        ]
        let settings = try! SettingsViewModel(dictSettings: dictSettings)
        settings.dictLoadingStatuses = [
            "SKK-JISYO.L": .loaded(success: 123456, failure: 789),
            "SKK-JISYO.sample.utf-8": .disabled,
            "SKK-JISYO.dummy": .loading,
            "SKK-JISYO.error": .fail(DictionariesViewPreviewError.dummy)
        ]
        return settings
    }

    static var previews: some View {
        DictionariesView(settingsViewModel: makeSettingsViewModel())
        DictionariesView(settingsViewModel: try! SettingsViewModel(dictSettings: [])).previewDisplayName("辞書が空のとき")
    }
}
