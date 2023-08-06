// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// 注釈表示
struct AnnotationView: View {
    @Binding var annotation: String?
    @Binding var systemAnnotation: String?

    var body: some View {
        VStack(alignment: .leading) {
            if let systemAnnotation {
                Text("システム辞書")
                    .font(.headline)
                Text(systemAnnotation)
                    // FIXME: .textSelectionを有効にするとpopover内のテキスト選択ができるようになるが、
                    // ダークモードでは文字色が白から黒に変わってしまう問題がある。
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
                    .padding(.leading)
            }
            if let annotation {
                Text("SKK辞書")
                    .font(.headline)
                Text(annotation)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
                    .padding(.leading)
            }
        }
        .padding()
    }
}

struct AnnotationView_Previews: PreviewProvider {
    static var previews: some View {
        AnnotationView(
            annotation: .constant(String(repeating: "これは辞書の注釈です。", count: 3)),
            systemAnnotation: .constant(nil)
        )
        .frame(width: 300)
        .previewDisplayName("SKK辞書の注釈のみ")
        AnnotationView(
            annotation: .constant("これは辞書の注釈です"),
            systemAnnotation: .constant(String(repeating: "これはシステム辞書の注釈です。", count: 10))
        )
        .frame(width: 300)
        .previewDisplayName("SKK辞書の注釈 & システム辞書の注釈")
    }
}
