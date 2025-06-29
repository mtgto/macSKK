// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

// 日付変換設定画面
struct DateConversionsView: View {
    @StateObject var settingsViewModel: SettingsViewModel
    
    @State var selectedYomiIndex: Int? = nil
    @State var editingYomi: String?
    @FocusState var focusedYomiIndex: Int?
    @State var selectedDateConversionId: UUID? = nil
    // 変換候補の作成・編集画面を開いているかどうか
    @State var isShowingEditingDateConversion: Bool = false
    // 作成・編集している変換候補
    @State var editingDateConversionId: UUID? = nil
    @Environment(\.defaultMinListRowHeight) var defaultMinListRowHeight

    init(settingsViewModel: SettingsViewModel) {
        _settingsViewModel = StateObject(wrappedValue: settingsViewModel)
    }

    var body: some View {
        VStack(alignment: .leading) {
            Form {
                Section {
                    List {
                        ForEach(settingsViewModel.dateYomis, id: \.self) { yomi in
                            Text(yomi.yomi)
                        }
                    }
                    .listFooterControls(addAction: {
                        // yomis.append("")
                        // focusedYomiIndex = yomis.count - 1
                    }, removeAction: {
                        // if let selectedYomiIndex {
                        //     yomis.remove(at: selectedYomiIndex)
                        //     settingsViewModel.dateYomis = yomis
                        // }
                    })
                } header: {
                    Text("Yomi")
                }
                Section {
                    List(settingsViewModel.dateConvertions, selection: $selectedDateConversionId) { dateConversion in
                        Text(dateConversion.dateFormatter.string(for: Date()) ?? dateConversion.format)
                            .padding(.vertical, 4.0)
                    }
                    .listFooterControls(addAction: {
                        editingDateConversionId = nil
                        isShowingEditingDateConversion = true
                    }, removeAction: {
                        if let selectedDateConversionId {
                            settingsViewModel.dateConvertions.removeAll { $0.id == selectedDateConversionId }
                        }
                    })
                    .contextMenu(forSelectionType: UUID.self, menu: { _ in }) { dataConversionIds in
                        if let id = dataConversionIds.first {
                            editingDateConversionId = id
                            isShowingEditingDateConversion = true
                        }
                    }
                } header: {
                    Text("Conversion Candidates")
                }
            }
            .formStyle(.grouped)
        }.sheet(isPresented: $isShowingEditingDateConversion) {
            let dateConversion = settingsViewModel.dateConvertions.first(where: { $0.id == editingDateConversionId })
            DateConversionView(settingsViewModel: settingsViewModel,
                               id: $editingDateConversionId,
                               format: dateConversion?.format ?? "",
                               locale: dateConversion?.locale ?? .enUS,
                               calendar: dateConversion?.calendar ?? .gregorian,
                               isShowingSheet: $isShowingEditingDateConversion)
        }
    }
}

#Preview {
    DateConversionsView(settingsViewModel: try! SettingsViewModel())
}
