// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct DateYomiView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var settingsViewModel: SettingsViewModel
    @State private var yomi: String = ""
    @State private var relative: DateConversion.Yomi.RelativeTime = .now

    var body: some View {
        VStack {
            Form {
                Section {
                    TextField("Yomi", text: $yomi, prompt: Text("today"))
                    Picker("Relative Time", selection: $relative) {
                        ForEach(DateConversion.Yomi.RelativeTime.allCases, id: \.self) { time in
                            Text(time.localized).tag(time)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                Button {
                    let newYomi = DateConversion.Yomi(yomi: yomi, relative: relative)
                    settingsViewModel.dateYomis.append(newYomi)
                    dismiss()
                } label: {
                    Text("Done")
                        .padding([.leading, .trailing])
                }
                .keyboardShortcut(.defaultAction)
                .disabled(yomi.isEmpty)
            }
            .padding()
        }
    }
}

#Preview {
    DateYomiView(settingsViewModel: try! SettingsViewModel())
}
