// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// 注釈表示
struct AnnotationView: View {
    @Binding var annotations: [Annotation]
    @Binding var systemAnnotation: String?
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading) {
            ScrollView {
                if let systemAnnotation {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading) {
                            Text("システム辞書")
                                .font(.headline)
                            Text(systemAnnotation)
                                .textSelection(.enabled)
                                // ↓ ダークモードではテキスト選択時に文字色が白から黒に変わってしまう問題があるので暫定対処
                                .foregroundColor(colorScheme == .dark ? .white : nil)
                                .fixedSize(horizontal: false, vertical: true)
                                .layoutPriority(1)
                                .padding(.leading)
                        }
                        Spacer()
                    }
                }
                HStack(alignment: .top) {
                    VStack(alignment: .leading) {
                        ForEach(annotations, id: \.dictId) { annotation in
                            Text(annotation.dictId)
                                .font(.headline)
                            Text(annotation.text)
                                .textSelection(.enabled)
                                .foregroundColor(colorScheme == .dark ? .white : nil)
                                .fixedSize(horizontal: false, vertical: true)
                                .layoutPriority(1)
                                .padding(.leading)
                        }
                    }
                    Spacer()
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}

struct AnnotationView_Previews: PreviewProvider {
    static var previews: some View {
        AnnotationView(
            annotations: .constant([Annotation(dictId: "SKK-JISYO.L", text: "これは辞書の注釈です。")]),
            systemAnnotation: .constant(nil)
        )
        .frame(width: 300)
        .previewDisplayName("SKK辞書の注釈のみ")
        AnnotationView(
            annotations: .constant([Annotation(dictId: "SKK-JISYO.L", text: "これは辞書の注釈です。"),
                                    Annotation(dictId: Annotation.userDictId, text: "これはユーザー辞書の注釈です。")]),
            systemAnnotation: .constant(nil)
        )
        .frame(width: 300)
        .previewDisplayName("SKK辞書の注釈 + ユーザー辞書の注釈")
        AnnotationView(
            annotations: .constant([Annotation(dictId: "SKK-JISYO.L", text: "これは辞書の注釈です。")]),
            systemAnnotation: .constant(String(repeating: "これはシステム辞書の注釈です。", count: 10))
        )
        .frame(width: 300)
        .previewDisplayName("SKK辞書の注釈 & システム辞書の注釈")
    }
}
