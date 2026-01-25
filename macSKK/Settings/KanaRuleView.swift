// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct KanaRuleView: View {
    @StateObject var settingsViewModel: SettingsViewModel

    var body: some View {
        VStack {
            Form {
                Picker("Behavior of Comma", selection: $settingsViewModel.comma) {
                    ForEach(Punctuation.Comma.allCases, id: \.id) { comma in
                        Text(comma.description).tag(comma)
                    }
                }
                Picker("Behavior of Period", selection: $settingsViewModel.period) {
                    ForEach(Punctuation.Period.allCases, id: \.id) { period in
                        Text(period.description).tag(period)
                    }
                }
                Section {
                    Text("TODO: Choose kanaRule")
                } footer: {
                    Button {

                    } label: {
                        Text("Show Settings in Finder")
                    }
                }
            }
            .formStyle(.grouped)
        }
    }
}

#Preview {
    KanaRuleView(settingsViewModel: try! SettingsViewModel())
}
