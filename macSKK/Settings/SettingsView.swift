// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct SettingsView: View {
    enum Section: CaseIterable {
        case general, keyEvent, systemDict
    }
    @StateObject var settingsViewModel: SettingsViewModel
    @State private var selectedSection: Section = .general

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            List(Section.allCases, id: \.self, selection: $selectedSection) { section in
                NavigationLink(value: section) {
                    switch section {
                    case .general:
                        Label("General", systemImage: "gearshape")
                    case .keyEvent:
                        Label("KeyEvent", systemImage: "keyboard")
                    case .systemDict:
                        Label("SystemDict", systemImage: "book.closed.fill")
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(215)
        } detail: {
            switch selectedSection {
            case .general:
                GeneralView(settingsViewModel: settingsViewModel)
                    .navigationTitle("General")
            case .keyEvent:
                KeyEventView()
                    .navigationTitle("KeyEvent")
            case .systemDict:
                SystemDictView()
                    .navigationTitle("SystemDict")
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
        SettingsView(settingsViewModel: SettingsViewModel())
    }
}
