// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// 補完候補を表示するビュー
struct CompletionView: View {
    @ObservedObject var viewModel: CompletionViewModel

    var body: some View {
        VStack {
            Text(viewModel.completion)
                .font(.body)
            Text("Tab Completion")
                .font(.caption)
                .frame(maxWidth: .infinity)
        }
        .padding(2)
        .fixedSize()
    }
}

struct CompletionView_Previews: PreviewProvider {
    static var previews: some View {
        CompletionView(viewModel: CompletionViewModel(completion: "あいうえおかきくけこさしすせそ"))
    }
}
