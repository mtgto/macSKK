// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct InputModeView: View {
    @ObservedObject var viewModel: InputModeViewModel

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Image(viewModel.privateMode ? "mode-lock" : "mode-triangle")
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(viewModel.primary)
                .frame(width: 13, height: 13)
                .padding(.leading, 2)
            Image(viewModel.imageForInputMode)
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(viewModel.primary)
                .frame(width: 18, height: 18)
                .padding(.trailing, 1)
                .padding(.leading, -0.5)
        }
        .frame(width: 33, height: 24)
        .background(
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(viewModel.background)
        )
    }
}

struct InputModeView_Previews: PreviewProvider {
    static var previews: some View {
        Grid {
            GridRow {
                InputModeView(viewModel: InputModeViewModel(inputMode: .hiragana, privateMode: false))
                InputModeView(viewModel: InputModeViewModel(inputMode: .katakana, privateMode: false))
                InputModeView(viewModel: InputModeViewModel(inputMode: .hankaku, privateMode: false))
                InputModeView(viewModel: InputModeViewModel(inputMode: .eisu, privateMode: false))
                InputModeView(viewModel: InputModeViewModel(inputMode: .direct, privateMode: false))
            }
            GridRow {
                InputModeView(viewModel: InputModeViewModel(inputMode: .hiragana, privateMode: true))
                InputModeView(viewModel: InputModeViewModel(inputMode: .katakana, privateMode: true))
                InputModeView(viewModel: InputModeViewModel(inputMode: .hankaku, privateMode: true))
                InputModeView(viewModel: InputModeViewModel(inputMode: .eisu, privateMode: true))
                InputModeView(viewModel: InputModeViewModel(inputMode: .direct, privateMode: true))
            }
            GridRow {
                InputModeView(viewModel: InputModeViewModel(inputMode: .hiragana, privateMode: false, inputModeColorSets: [.hiragana: InputModeColorSet(textColor: .white, backgroundColor: .black)]))
                InputModeView(viewModel: InputModeViewModel(inputMode: .katakana, privateMode: false, inputModeColorSets: [.katakana: InputModeColorSet(textColor: .white, backgroundColor: .orange)]))
                InputModeView(viewModel: InputModeViewModel(inputMode: .hankaku, privateMode: false, inputModeColorSets: [.hankaku: InputModeColorSet(textColor: .white, backgroundColor: .green)]))
                InputModeView(viewModel: InputModeViewModel(inputMode: .eisu, privateMode: false, inputModeColorSets: [.eisu: InputModeColorSet(textColor: .white, backgroundColor: .blue)]))
                InputModeView(viewModel: InputModeViewModel(inputMode: .direct, privateMode: false, inputModeColorSets: [.direct: InputModeColorSet(textColor: .white, backgroundColor: .purple)]))
            }
        }
        .scaleEffect(2.0)
        .frame(width: 480, height: 240)
        .background(.cyan)
        .previewLayout(.sizeThatFits)
    }
}
