// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// 変換候補ビュー
/// とりあえず10件ずつ縦に表示、スペースで次の10件が表示される
struct CandidatesView: View {
    @ObservedObject var candidates: CandidatesViewModel
    static let footerHeight: CGFloat = 20
    /// 変換候補と注釈の間
    static let annotationMargin: CGFloat = 8
    /// パネル型の注釈ビューの幅
    static let annotationPopupWidth: CGFloat = 300
    /// パネル型の注釈ビューの縦幅
    static let annotationPopupHeightInHorzontalMode: CGFloat = 120

    var body: some View {
        switch candidates.candidates {
        case .inline:
            AnnotationView(annotations: $candidates.selectedAnnotations, systemAnnotation: $candidates.selectedSystemAnnotation, annotationFontSize: candidates.annotationFontSize)
                .padding(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
                .frame(width: 300, height: 200)
                .background()
        case let .panel(words, currentPage, totalPageCount):
            if candidates.displayCandidatesHorizontally {
                HorizontalCandidatesView(candidates: candidates, words: words, currentPage: currentPage, totalPageCount: totalPageCount)
            } else {
                VerticalCandidatesView(candidates: candidates, words: words, currentPage: currentPage, totalPageCount: totalPageCount)
            }
        }
    }
}
