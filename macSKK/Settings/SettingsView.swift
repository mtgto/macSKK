// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct SettingsView: View {
    enum Section {
        case general, keyEvent, systemDict
    }
    var body: some View {
        TabView {
            GeneralView()
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
        }
        .frame(minWidth: 640, minHeight: 360)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
