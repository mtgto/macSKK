// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

enum SettingSection: String, Identifiable {
    var id: Self { self }

    case general = "General"
    case keyEvent = "KeyEvent"
}

struct SettingsView: View {
    private var sections: [SettingSection] = [.general, .keyEvent]
    @State private var selectedSection: SettingSection?

    var body: some View {
        NavigationSplitView {
            List(sections, selection: $selectedSection) { section in
                Text(section.rawValue)
            }
        } detail: {
            if case .general = selectedSection {
                Text("General")
            } else if case .keyEvent = selectedSection {
                KeyEventView()
            } else {
                Text(selectedSection?.rawValue ?? "None")
            }
        }.onAppear {
            selectedSection = sections.first
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
