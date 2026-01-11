// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// 変換候補ビュー
/// とりあえず10件ずつ縦に表示、スペースで次の10件が表示される
struct CandidatesView: View {
    @ObservedObject var candidates: CandidatesViewModel
    static let footerHeight: CGFloat = 20
    /// 縦表示の変換候補と注釈の間 (左右の余白)
    static let annotationMarginLeftRight: CGFloat = 8
    /// 横表示の変換候補と注釈の間 (上下の余白)
    static let annotationMarginTopBottom: CGFloat = 4
    /// パネル型の注釈ビューの幅
    static let annotationPopupWidth: CGFloat = 300

    var body: some View {
        switch candidates.candidates {
        case .inline:
            AnnotationView(
                annotations: $candidates.selectedAnnotations,
                systemAnnotation: $candidates.selectedSystemAnnotation,
                font: $candidates.annotationFont
            )
            .padding(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
            .frame(width: 300, height: 200)
            .optionalBackground(candidates.annotationBackgroundColor)
            .background()
        case let .panel(words, currentPage, totalPageCount):
            switch Global.candidateListDirection.value {
            case .vertical:
                VerticalCandidatesView(candidates: candidates, words: words, currentPage: currentPage, totalPageCount: totalPageCount)
            case .horizontal:
                HorizontalCandidatesView(candidates: candidates, words: words, currentPage: currentPage, totalPageCount: totalPageCount)
            }
        }
    }
}
