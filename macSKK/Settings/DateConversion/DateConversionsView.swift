// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

// 日付変換設定画面
struct DateConversionsView: View {
    @StateObject var settingsViewModel: SettingsViewModel
    
    @State private var selectedYomiId: UUID?
    @State private var selectedDateConversionId: UUID?
    // 読みの作成・編集画面を開いているかどうか
    @State var isShowingEditingYomiSheet: Bool = false
    // 変換候補の作成・編集画面を開いているかどうか
    @State var isShowingEditingDateConversionSheet: Bool = false
    // 作成・編集している変換候補
    @State var editingDateConversionId: UUID? = nil
    // 作成・編集している変換候補
    @State var editingYomiId: UUID? = nil
    @Environment(\.defaultMinListRowHeight) var defaultMinListRowHeight

    var body: some View {
        VStack(alignment: .leading) {
            Form {
                Section {
                    List(selection: $selectedYomiId) {
                        ForEach(settingsViewModel.dateYomis) { yomi in
                            Text(yomi.yomi)
                                .padding(.vertical, 4.0)
                        }
                        .onMove { (indexSet, destination) in
                            settingsViewModel.dateYomis.move(fromOffsets: indexSet, toOffset: destination)
                        }
                    }
                    .listFooterControls(addAction: {
                        isShowingEditingYomiSheet = true
                    }, removeAction: {
                        if let selectedYomiId {
                            settingsViewModel.dateYomis.removeAll { $0.id == selectedYomiId }
                        }
                    })
                    .contextMenu(forSelectionType: UUID.self, menu: { _ in }) { dataYomiIds in
                        if let id = dataYomiIds.first {
                            editingYomiId = id
                            isShowingEditingYomiSheet = true
                        }
                    }
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
                        isShowingEditingDateConversionSheet = true
                    }, removeAction: {
                        if let selectedDateConversionId {
                            settingsViewModel.dateConvertions.removeAll { $0.id == selectedDateConversionId }
                        }
                    })
                    .contextMenu(forSelectionType: UUID.self, menu: { _ in }) { dataConversionIds in
                        if let id = dataConversionIds.first {
                            editingDateConversionId = id
                            isShowingEditingDateConversionSheet = true
                        }
                    }
                } header: {
                    Text("Conversion Candidates")
                }
            }
            .formStyle(.grouped)
        }
        .sheet(isPresented: $isShowingEditingYomiSheet) {
            let dateYomi = settingsViewModel.dateYomis.first(where: { $0.id == editingYomiId })
            DateYomiView(settingsViewModel: settingsViewModel,
                         id: $editingYomiId,
                         yomi: dateYomi?.yomi ?? "",
                         relative: dateYomi?.relative ?? .now)
        }
        .sheet(isPresented: $isShowingEditingDateConversionSheet) {
            let dateConversion = settingsViewModel.dateConvertions.first(where: { $0.id == editingDateConversionId })
            DateConversionView(settingsViewModel: settingsViewModel,
                               id: $editingDateConversionId,
                               format: dateConversion?.format ?? "",
                               locale: dateConversion?.locale ?? .enUS,
                               calendar: dateConversion?.calendar ?? .gregorian)
        }
    }
}

#Preview {
    DateConversionsView(settingsViewModel: try! SettingsViewModel())
}
