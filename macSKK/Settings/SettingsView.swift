// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct SettingSection: Identifiable, Hashable {
    var id = UUID()
    var name: String
}

enum Sections: Identifiable, Hashable {
    var id: Self {
        return self
    }

    case general
    case keyEvent
}

struct SettingsView: View {
    private var sections: [SettingSection] = [SettingSection(name: "General")]
    @State private var selectedSectionId: SettingSection.ID?

    var body: some View {
        NavigationSplitView {
            List(sections, selection: $selectedSectionId) { section in
                Text(section.name)
            }
        } detail: {
            Text("Hoge")
        }.onAppear {
            selectedSectionId = sections.first?.id
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
