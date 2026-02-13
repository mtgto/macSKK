// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct InputModeSettingsView: View {
    @State var textColor: String = ""
    var body: some View {
        VStack {
            HStack {
                List {
                    Text("ABC")
                    Text("Hiragana")
                    Text("Katakana")
                    Text("Hankaku")
                    Text("Eisu")
                }
                .frame(width: 200)
                VStack {
                    Picker("Text Color", selection: $textColor) {
                        Text("Default")
                    }
                    Picker("Background Color", selection: $textColor) {
                        Text("Default")
                    }
                    Button("Return to default") {

                    }
                }
            }
            HStack {
                InputModeView(viewModel: InputModeViewModel(primary: .white, background: .black, inputMode: .direct, privateMode: false))
                InputModeView(viewModel: InputModeViewModel(primary: .white, background: .orange, inputMode: .hiragana, privateMode: false))
                InputModeView(viewModel: InputModeViewModel(primary: .white, background: .green, inputMode: .katakana, privateMode: false))
                InputModeView(viewModel: InputModeViewModel(primary: .white, background: .blue, inputMode: .hankaku, privateMode: false))
                InputModeView(viewModel: InputModeViewModel(primary: .white, background: .purple, inputMode: .eisu, privateMode: false))
            }
            .scaleEffect(2)
            .padding()
        }
        .padding()
    }
}

#Preview {
    InputModeSettingsView()
}
