// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct HorizontalCandidatesView: View {
    /// パネル型の注釈ビューの縦幅
    /// TODO: 内容によって可変にしたい
    static let annotationPopupHeight: CGFloat = 120

    @ObservedObject var candidates: CandidatesViewModel

    let words: [Candidate]
    let currentPage: Int
    let totalPageCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: CandidatesView.annotationMarginTopBottom) {
            if candidates.displayPopoverInLeftOrTop {
                if candidates.popoverIsPresented {
                    AnnotationView(
                        annotations: $candidates.selectedAnnotations,
                        systemAnnotation: $candidates.selectedSystemAnnotation,
                        annotationFontSize: candidates.annotationFontSize
                    )
                    .padding(EdgeInsets(top: 16, leading: 12, bottom: 16, trailing: 8))
                    .frame(width: CandidatesView.annotationPopupWidth, height: Self.annotationPopupHeight, alignment: .topLeading)
                    .fixedSize(horizontal: false, vertical: true)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .opacity(0.9)
                } else {
                    Spacer(minLength: Self.annotationPopupHeight)
                }
            }
            HStack(spacing: 0) {
                ForEach(Array(words.enumerated()), id: \.element) { index, candidate in
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text(String(Global.selectCandidateKeys[index]).uppercased())
                            // 変換候補の90%のフォントサイズ
                            .font(.system(size: candidates.candidatesFontSize * 0.9))
                            // 目立たないようにする
                            .foregroundStyle(candidates.selected == candidate ? Color(NSColor.selectedMenuItemTextColor.withAlphaComponent(0.8)) : Color(NSColor.secondaryLabelColor))
                            .frame(width: 16, alignment: .trailing)
                            .padding(.trailing, 4)
                        Text(candidate.word)
                            .font(.system(size: candidates.candidatesFontSize))
                            .foregroundStyle(candidates.selected == candidate ? Color(NSColor.selectedMenuItemTextColor) : Color(NSColor.textColor))
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.trailing, 8)
                    }
                    .frame(height: candidates.candidatesLineHeight)
                    .background(candidates.selected == candidate ? Color.accentColor : Color.clear)
                }
                Text("\(currentPage + 1) / \(totalPageCount)")
                    .foregroundStyle(Color(NSColor.secondaryLabelColor))
                    .padding([.leading, .trailing], 4)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .background()
            if candidates.popoverIsPresented && !candidates.displayPopoverInLeftOrTop {
                AnnotationView(
                    annotations: $candidates.selectedAnnotations,
                    systemAnnotation: $candidates.selectedSystemAnnotation,
                    annotationFontSize: candidates.annotationFontSize
                )
                .padding(EdgeInsets(top: 16, leading: 28, bottom: 16, trailing: 4))
                .frame(width: CandidatesView.annotationPopupWidth, height: Self.annotationPopupHeight, alignment: .topLeading)
                .fixedSize(horizontal: false, vertical: /*@START_MENU_TOKEN@*/true/*@END_MENU_TOKEN@*/)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                .opacity(0.9)
            }
        }
        .background(Color.clear)
    }
}

struct HorizonalCandidatesView_Previews: PreviewProvider {
    private static let words: [Candidate] = (1...9).map {
        Candidate("\(String(repeating: "例文", count: $0 % 4 + 1))", annotations: [Annotation(dictId: "SKK-JISYO.L", text: "注釈\($0)")])
    }

    private static func pageViewModel() -> CandidatesViewModel {
        let viewModel = CandidatesViewModel(candidates: words, currentPage: 0, totalPageCount: 3, showAnnotationPopover: true)
        viewModel.selected = words.first
        viewModel.systemAnnotations = [words.first!.word: String(repeating: "これはシステム辞書の注釈です。", count: 20)]
        viewModel.maxWidth = 1000
        return viewModel
    }

    private static func pageViewModelUpPopover() -> CandidatesViewModel {
        let viewModel = CandidatesViewModel(candidates: words, currentPage: 0, totalPageCount: 3, showAnnotationPopover: true)
        viewModel.selected = words.first
        viewModel.systemAnnotations = [words.first!.word: String(repeating: "これはシステム辞書の注釈です。", count: 20)]
        viewModel.maxWidth = 1000
        viewModel.maxHeight = 1
        return viewModel
    }

    private static func pageViewModelShortAnnotation() -> CandidatesViewModel {
        let viewModel = CandidatesViewModel(candidates: words, currentPage: 0, totalPageCount: 3, showAnnotationPopover: true)
        viewModel.selected = words.first
        viewModel.systemAnnotations = [:]
        viewModel.maxWidth = 1000
        return viewModel
    }

    private static func pageWithoutPopoverViewModel() -> CandidatesViewModel {
        let viewModel = CandidatesViewModel(candidates: words, currentPage: 0, totalPageCount: 3, showAnnotationPopover: false)
        viewModel.selected = words.first
        viewModel.systemAnnotations = [words.first!.word: String(repeating: "これはシステム辞書の注釈です。", count: 10)]
        return viewModel
    }

    private static func inlineViewModel() -> CandidatesViewModel {
        let viewModel = CandidatesViewModel(candidates: words, currentPage: 0, totalPageCount: 3, showAnnotationPopover: true)
        viewModel.candidates = .inline
        viewModel.selected = words.first
        viewModel.systemAnnotations = [words.first!.word: String(repeating: "これはシステム辞書の注釈です。", count: 10)]
        return viewModel
    }

    private static func fontSize19ViewModel() -> CandidatesViewModel {
        let viewModel = CandidatesViewModel(candidates: words, currentPage: 0, totalPageCount: 3, showAnnotationPopover: true, candidatesFontSize: CGFloat(19), annotationFontSize: CGFloat(19))
        viewModel.selected = words.first
        viewModel.systemAnnotations = [words.first!.word: String(repeating: "これはシステム辞書の注釈です。", count: 20)]
        viewModel.maxWidth = 1000
        return viewModel
    }

    static var previews: some View {
        HorizontalCandidatesView(candidates: pageViewModel(), words: words, currentPage: 9, totalPageCount: 10)
            .background(Color.cyan)
            .previewDisplayName("パネル表示")
        HorizontalCandidatesView(candidates: pageViewModelUpPopover(), words: words, currentPage: 0, totalPageCount: 3)
            .background(Color.cyan)
            .previewDisplayName("パネル表示 (注釈上)")
        HorizontalCandidatesView(candidates: pageViewModelShortAnnotation(), words: words, currentPage: 0, totalPageCount: 3)
            .background(Color.cyan)
            .previewDisplayName("パネル表示 (注釈短い)")
        HorizontalCandidatesView(candidates: pageWithoutPopoverViewModel(), words: words, currentPage: 0, totalPageCount: 3)
            .previewDisplayName("パネル表示 (注釈なし)")
        HorizontalCandidatesView(candidates: inlineViewModel(), words: words, currentPage: 0, totalPageCount: 3)
            .previewDisplayName("インライン表示")
        HorizontalCandidatesView(candidates: fontSize19ViewModel(), words: words, currentPage: 0, totalPageCount: 3)
            .background(Color.cyan)
            .previewDisplayName("フォントサイズ19")
    }
}
