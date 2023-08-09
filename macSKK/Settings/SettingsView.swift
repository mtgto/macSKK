// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct SettingsView: View {
    enum Section {
        case general, keyEvent, systemDict
    }
    @StateObject var settingsViewModel: SettingsViewModel

    var body: some View {
        TabView {
            #if DEBUG
            GeneralView(settingsViewModel: settingsViewModel)
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag(Section.general)
            KeyEventView()
                .tabItem {
                    Label("KeyEvent", systemImage: "keyboard")
                }
                .tag(Section.keyEvent)
            SystemDictView()
                .tabItem {
                    Label("SystemDict", systemImage: "book.closed.fill")
                }
                .tag(Section.systemDict)
            #else
                Text("TODO")
            #endif
        }
        .frame(minWidth: 640, minHeight: 360)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(settingsViewModel: SettingsViewModel())
    }
}
