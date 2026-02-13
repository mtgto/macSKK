// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct InputModeSettingsView: View {
    @ObservedObject var settingsViewModel: SettingsViewModel

    private func binding(for mode: InputMode) -> Binding<InputModeColorSet> {
        Binding(
            get: { settingsViewModel.inputModeColorSets[mode, default: .defaultColorSet] },
            set: { settingsViewModel.inputModeColorSets[mode] = $0 }
        )
    }

    private func label(for mode: InputMode) -> LocalizedStringKey {
        switch mode {
        case .direct: return "ABC"
        case .hiragana: return "Hiragana"
        case .katakana: return "Katakana"
        case .hankaku: return "Hankaku"
        case .eisu: return "Zenkaku"
        }
    }

    var body: some View {
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
                    Text(label(for: mode))
                    ColorPicker("", selection: binding(for: mode).textColor)
                        .labelsHidden()
                    ColorPicker("", selection: binding(for: mode).backgroundColor)
                        .labelsHidden()
                    let setting = settingsViewModel.inputModeColorSets[mode, default: .defaultColorSet]
                    InputModeView(viewModel: InputModeViewModel(
                        primary: setting.textColor,
                        background: setting.backgroundColor,
                        inputMode: mode,
                        privateMode: false
                    ))
                    .scaleEffect(1.5)
                    .frame(width: 44, height: 36)
                }
            }
        }
        .frame(width: 360, height: 300)
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
