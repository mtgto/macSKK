// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import Combine

// 日付変換設定画面
struct DateConversionsView: View {
    @StateObject var settingsViewModel: SettingsViewModel
    
    @State private var selectedYomiId: UUID?
    @State private var selectedDateConversionId: UUID?
    // 読みの作成画面を開いているかどうか
    @State var isAddingYomiSheet: Bool = false
    // 編集している読み
    @State var editingYomi: DateConversion.Yomi? = nil
    // 変換候補の作成画面を開いているかどうか
    @State var isAddingDateConversionSheet: Bool = false
    // 編集している変換候補
    @State var editingDateConversion: DateConversion? = nil
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
                        isAddingYomiSheet = true
                    }, removeAction: {
                        if let selectedYomiId {
                            settingsViewModel.dateYomis.removeAll { $0.id == selectedYomiId }
                        }
                    })
                    .contextMenu(forSelectionType: UUID.self, menu: { _ in }) { dataYomiIds in
                        if let id = dataYomiIds.first, let dateYomi = settingsViewModel.dateYomis.first(where: { $0.id == id }) {
                            editingYomi = dateYomi
                        }
                    }
                } header: {
                    Text("Yomi")
                }
                Section {
                    List(selection: $selectedDateConversionId) {
                        ForEach(settingsViewModel.dateConversions) { dateConversion in
                            Text(dateConversion.dateFormatter.string(for: Date()) ?? dateConversion.format)
                                .padding(.vertical, 4.0)
                        }
                        .onMove { (indexSet, destination) in
                            settingsViewModel.dateConversions.move(fromOffsets: indexSet, toOffset: destination)
                        }
                    }
                    .listFooterControls(addAction: {
                        isAddingDateConversionSheet = true
                    }, removeAction: {
                        if let selectedDateConversionId {
                            settingsViewModel.dateConversions.removeAll { $0.id == selectedDateConversionId }
                        }
                    })
                    .contextMenu(forSelectionType: UUID.self, menu: { _ in }) { dataConversionIds in
                        if let id = dataConversionIds.first, let dateConversion = settingsViewModel.dateConversions.first(where: { $0.id == id }) {
                            editingDateConversion = dateConversion
                        }
                    }
                } header: {
                    Text("Conversion Candidates")
                    Text("SettingsDateConversionSubtitle")
                        .font(.subheadline)
                        .fontWeight(.light)
                }
            }
            .formStyle(.grouped)
        }
        .sheet(isPresented: $isAddingYomiSheet) {
            DateYomiView(settingsViewModel: settingsViewModel,
                         id: nil,
                         yomi: "",
                         relative: .now)
        }
        .sheet(item: $editingYomi) { dateYomi in
            DateYomiView(settingsViewModel: settingsViewModel,
                         id: dateYomi.id,
                         yomi: dateYomi.yomi,
                         relative: dateYomi.relative)
        }
        .sheet(isPresented: $isAddingDateConversionSheet) {
            DateConversionView(
                settingsViewModel: settingsViewModel,
                id: nil,
                inputs: DateConversionView.Inputs(
                    format: "",
                    locale: .enUS,
                    calendar: .gregorian))
        }
        .sheet(item: $editingDateConversion) { dateConversion in
            DateConversionView(
                settingsViewModel: settingsViewModel,
                id: dateConversion.id,
                inputs: DateConversionView.Inputs(
                    format: dateConversion.format,
                    locale: dateConversion.locale,
                    calendar: dateConversion.calendar))
        }
    }
}

#Preview {
    DateConversionsView(settingsViewModel: try! SettingsViewModel())
}
