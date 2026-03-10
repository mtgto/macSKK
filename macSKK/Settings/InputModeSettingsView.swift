// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct InputModeSettingsView: View {
    @ObservedObject var settingsViewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            Grid(alignment: .center, horizontalSpacing: 24, verticalSpacing: 12) {
                GridRow {
                    Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                    Text("文字色").foregroundStyle(.secondary)
                    Text("背景色").foregroundStyle(.secondary)
                    Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                }
                Divider()
                    .gridCellUnsizedAxes(.horizontal)
                    .gridCellColumns(4)
                ForEach(InputMode.allCases, id: \.self) { mode in
                    GridRow {
                        Text(mode.localizedLabel)
                        ColorPicker("", selection: colorSet(for: mode).textColor)
                            .labelsHidden()
                        ColorPicker("", selection: colorSet(for: mode).backgroundColor)
                            .labelsHidden()
                        let setting = settingsViewModel.inputModeColorSets[mode, default: .defaultColorSet]
                        InputModeView(viewModel: InputModeViewModel(
                            inputMode: mode,
                            privateMode: false,
                            inputModeColorSets: [mode: setting]
                        ))
                    }
                }
            }
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .padding([.leading, .trailing])
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .padding()
        .frame(width: 360, height: 300)
    }

    private func colorSet(for mode: InputMode) -> Binding<InputModeColorSet> {
        Binding(
            get: { settingsViewModel.inputModeColorSets[mode, default: .defaultColorSet] },
            set: { settingsViewModel.inputModeColorSets[mode] = $0 }
        )
    }
}

#Preview {
    InputModeSettingsView(settingsViewModel: try! SettingsViewModel(inputModeColorSets: [
        .hiragana: InputModeColorSet(textColor: .white, backgroundColor: .orange),
        .katakana: InputModeColorSet(textColor: .white, backgroundColor: .green),
        .hankaku: InputModeColorSet(textColor: .white, backgroundColor: .blue),
        .eisu: InputModeColorSet(textColor: .white, backgroundColor: .purple),
        .direct: InputModeColorSet(textColor: .white, backgroundColor: .black),
    ]))
}
