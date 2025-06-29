// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct DateYomiView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var settingsViewModel: SettingsViewModel
    @Binding var id: UUID?
    @State var yomi: String
    @State var relative: DateConversion.Yomi.RelativeTime

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
                    if let id, let index = settingsViewModel.dateYomis.firstIndex(where: { $0.id == id }) {
                        settingsViewModel.dateYomis[index] = DateConversion.Yomi(id: id, yomi: yomi, relative: relative)
                    } else {
                        let newYomi = DateConversion.Yomi(yomi: yomi, relative: relative)
                        settingsViewModel.dateYomis.append(newYomi)
                    }
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
    DateYomiView(settingsViewModel: try! SettingsViewModel(),
                 id: .constant(nil),
                 yomi: "today",
                 relative: .now)
}
