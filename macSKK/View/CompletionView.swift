// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// 補完候補を表示するビュー
struct CompletionView: View {
    @ObservedObject var viewModel: CompletionViewModel

    var body: some View {
        VStack {
            Text(viewModel.completion)
                .font(.caption)
            Text("Tabで補完")
                .font(.caption)
                .frame(maxWidth: .infinity)
                .presentationBackground(.background)
        }
        .fixedSize()
    }
}

struct CompletionView_Previews: PreviewProvider {
    static var previews: some View {
        CompletionView(viewModel: CompletionViewModel(completion: "あいうえおかきくけこさしすせそ"))
    }
}
