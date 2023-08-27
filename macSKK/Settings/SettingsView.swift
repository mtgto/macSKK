// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct SettingsView: View {
    // rawValueはLocalizable.stringsのキー名
    enum Section: String, CaseIterable {
        case dictionaries = "SettingsNameDictionaries"
        case softwareUpdate = "SettingsNameSoftwareUpdate"
        case directMode = "SettingsNameDirectMode"
        #if DEBUG
        case keyEvent = "SettingsNameKeyEvent"
        case systemDict = "SettingsNameSystemDict"
        #endif

        var localizedStringKey: LocalizedStringKey { LocalizedStringKey(rawValue) }
    }
    @ObservedObject var settingsViewModel: SettingsViewModel
    @State private var selectedSection: Section = .dictionaries

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            List(Section.allCases, id: \.rawValue, selection: $selectedSection) { section in
                NavigationLink(value: section) {
                    switch section {
                    case .dictionaries:
                        Label(section.localizedStringKey, systemImage: "books.vertical")
                    case .softwareUpdate:
                        Label(section.localizedStringKey, systemImage: "gear.badge")
                    case .directMode:
                        Label(section.localizedStringKey, systemImage: "hand.raised.app")
                    #if DEBUG
                    case .keyEvent:
                        Label(section.localizedStringKey, systemImage: "keyboard")
                    case .systemDict:
                        Label(section.localizedStringKey, systemImage: "book.closed.fill")
                    #endif
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(215)
        } detail: {
            switch selectedSection {
            case .dictionaries:
                DictionariesView(settingsViewModel: settingsViewModel)
                    .navigationTitle(selectedSection.localizedStringKey)
            case .softwareUpdate:
                SoftwareUpdateView(settingsViewModel: settingsViewModel)
                    .navigationTitle(selectedSection.localizedStringKey)
            case .directMode:
                DirectModeView(bundleIdentifiers: $settingsViewModel.directModeBundleIdentifiers)
                    .navigationTitle(selectedSection.localizedStringKey)
            #if DEBUG
            case .keyEvent:
                KeyEventView()
                    .navigationTitle(selectedSection.localizedStringKey)
            case .systemDict:
                SystemDictView()
                    .navigationTitle(selectedSection.localizedStringKey)
            #endif
            }
        }
        .task(id: selectedSection) {
            updateWindowAndToolbar()
        }
        .frame(minWidth: 640, minHeight: 360)
    }

    // ウィンドウのスタイルの変更とツールバーからサイドバー切り替えのボタンを削除する
    func updateWindowAndToolbar() {
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "com_apple_SwiftUI_Settings_window" }) {
            window.titleVisibility = .visible
            window.titlebarAppearsTransparent = true
            window.styleMask = [.titled, .closable, .fullSizeContentView, .unifiedTitleAndToolbar]
            window.toolbarStyle = .unified
            // サイドバー切り替えボタンの削除はmacOS 14からはAPIが用意されるぽい
            // https://developer.apple.com/documentation/swiftui/view/toolbar(removing:)
            if let toolbar = window.toolbar {
                if let index = toolbar.items.firstIndex(where: { $0.itemIdentifier.rawValue == "com.apple.SwiftUI.navigationSplitView.toggleSidebar" }) {
                    toolbar.removeItem(at: index)
                }
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(settingsViewModel: try! SettingsViewModel(dictSettings: []))
    }
}
