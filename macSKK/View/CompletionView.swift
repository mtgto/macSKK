// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// 補完候補を表示するビュー
struct CompletionView: View {
    @ObservedObject var viewModel: CompletionViewModel
    static let footerHeight: CGFloat = 18

    var body: some View {
        VStack(spacing: 0) {
            if case .yomi(let yomi) = viewModel.completion {
                Text(yomi)
                    .font(.body)
            } else if case .candidates(let words) = viewModel.completion {
                if case .vertical = Global.candidateListDirection.value {
                    VerticalCandidatesView(candidates: viewModel.candidatesViewModel, words: words, currentPage: 0, totalPageCount: 1)
                } else {
                    HorizontalCandidatesView(candidates: viewModel.candidatesViewModel, words: words, currentPage: 0, totalPageCount: 1)
                }
            }
            Text("Tab Completion")
                .font(.caption)
                .frame(maxWidth: .infinity)
                .frame(height: Self.footerHeight)
        }
        .fixedSize()
    }
}

struct CompletionView_Previews: PreviewProvider {
    private static let words: [Candidate] = (1...9).map {
        Candidate(String(repeating: "例文\($0)", count: $0),
                  annotations: [Annotation(dictId: "SKK-JISYO.L", text: "注釈\($0)")])
    }

    static var previews: some View {
        CompletionView(
            viewModel: CompletionViewModel(completion: .yomi("あいうえおかきくけこさしすせそ"), candidatesFontSize: 13, annotationFontSize: 13)
        )
        .previewDisplayName("読み")
        CompletionView(
            viewModel: CompletionViewModel(
                completion: .candidates([
                    Candidate("平仮名"),
                    Candidate("片仮名"),
                    Candidate("漢字"),
                ]),
                candidatesFontSize: 13,
                annotationFontSize: 13)
        )
        .previewDisplayName("変換候補")
    }
}
