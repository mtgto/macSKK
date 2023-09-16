// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// 補完候補を表示するビュー
struct CompletionView: View {
    @Binding var completion: String

    var body: some View {
        VStack {
            Text(completion)
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
        CompletionView(completion: .constant("あいうえおかきくけこさしすせそ"))
            .preferredColorScheme(.light)
        CompletionView(completion: .constant("あいうえおかきくけこさしすせそ"))
            .preferredColorScheme(.dark)
    }
}
