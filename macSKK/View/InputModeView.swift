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
                .frame(width: 9, height: 9)
                .padding(.leading, 2)
//                .border(.red)
            Image(viewModel.imageForInputMode)
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(viewModel.primary)
                .frame(width: 12, height: 12)
                .padding(.trailing, 1)
                .padding(.leading, -0.5)
//                .border(.red)
        }
        .frame(width: 22, height: 16)
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
                InputModeView(viewModel: InputModeViewModel(primary: .black, background: .white, inputMode: .hiragana, privateMode: false))
                InputModeView(viewModel: InputModeViewModel(primary: .black, background: .white, inputMode: .katakana, privateMode: false))
                InputModeView(viewModel: InputModeViewModel(primary: .black, background: .white, inputMode: .hankaku, privateMode: false))
                InputModeView(viewModel: InputModeViewModel(primary: .black, background: .white, inputMode: .eisu, privateMode: false))
                InputModeView(viewModel: InputModeViewModel(primary: .black, background: .white, inputMode: .direct, privateMode: false))
            }
            GridRow {
                InputModeView(viewModel: InputModeViewModel(primary: .black, background: .white, inputMode: .hiragana, privateMode: true))
                InputModeView(viewModel: InputModeViewModel(primary: .black, background: .white, inputMode: .katakana, privateMode: true))
                InputModeView(viewModel: InputModeViewModel(primary: .black, background: .white, inputMode: .hankaku, privateMode: true))
                InputModeView(viewModel: InputModeViewModel(primary: .black, background: .white, inputMode: .eisu, privateMode: true))
                InputModeView(viewModel: InputModeViewModel(primary: .black, background: .white, inputMode: .direct, privateMode: true))
            }
            GridRow {
                InputModeView(viewModel: InputModeViewModel(primary: .white, background: .black, inputMode: .hiragana, privateMode: false))
                InputModeView(viewModel: InputModeViewModel(primary: .white, background: .orange, inputMode: .katakana, privateMode: false))
                InputModeView(viewModel: InputModeViewModel(primary: .white, background: .green, inputMode: .hankaku, privateMode: false))
                InputModeView(viewModel: InputModeViewModel(primary: .white, background: .blue, inputMode: .eisu, privateMode: false))
                InputModeView(viewModel: InputModeViewModel(primary: .white, background: .purple, inputMode: .direct, privateMode: false))
            }
        }
        .scaleEffect(4.0)
        .frame(width: 640, height: 320)
        .background(.cyan)
        .previewLayout(.sizeThatFits)
    }
}
