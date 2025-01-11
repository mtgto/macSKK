// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct HorizontalCandidatesView: View {
    @ObservedObject var candidates: CandidatesViewModel
    
    let words: [Candidate]
    let currentPage: Int
    let totalPageCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: CandidatesView.annotationMargin) {
            if candidates.displayPopoverInLeftOrTop {
                if candidates.popoverIsPresented {
                    AnnotationView(
                        annotations: $candidates.selectedAnnotations,
                        systemAnnotation: $candidates.selectedSystemAnnotation,
                        annotationFontSize: candidates.annotationFontSize
                    )
                    .padding(EdgeInsets(top: 16, leading: 12, bottom: 16, trailing: 8))
                    .frame(width: CandidatesView.annotationPopupWidth, height: CandidatesView.annotationPopupHeightInHorzontalMode, alignment: .topLeading)
                    .fixedSize(horizontal: false, vertical: /*@START_MENU_TOKEN@*/true/*@END_MENU_TOKEN@*/)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .opacity(0.9)
                } else {
                    Spacer(minLength: CandidatesView.annotationPopupWidth)
                }
            }
            HStack(spacing: 0) {
                ForEach(Array(words.enumerated()), id: \.element) { index, candidate in
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text(String(Global.selectCandidateKeys[index]).uppercased())
                        // 変換候補の90%のフォントサイズ
                            .font(.system(size: candidates.candidatesFontSize * 0.9))
                            .padding(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 0))
                            .frame(width: 16)
                        Text(candidate.word)
                            .font(.system(size: candidates.candidatesFontSize))
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 4))
                    }
                    .frame(height: candidates.candidatesLineHeight)
                    .foregroundStyle(candidates.selected == candidate ? Color(NSColor.highlightColor) : Color(NSColor.textColor))
                    .background(candidates.selected == candidate ? Color.accentColor : Color.clear)
                }
                Text("\(currentPage + 1) / \(totalPageCount)")
                    .padding(.trailing, 8)
                    .frame(width: 64, height: CandidatesView.footerHeight, alignment: .trailing)
            }
            .background()
            if candidates.popoverIsPresented && !candidates.displayPopoverInLeftOrTop {
                AnnotationView(
                    annotations: $candidates.selectedAnnotations,
                    systemAnnotation: $candidates.selectedSystemAnnotation,
                    annotationFontSize: candidates.annotationFontSize
                )
                .padding(EdgeInsets(top: 16, leading: 28, bottom: 16, trailing: 4))
                .frame(width: CandidatesView.annotationPopupWidth, height: CandidatesView.annotationPopupHeightInHorzontalMode, alignment: .topLeading)
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
        Candidate("例文\($0)", annotations: [Annotation(dictId: "SKK-JISYO.L", text: "注釈\($0)")])
    }

    private static func pageViewModel() -> CandidatesViewModel {
        let viewModel = CandidatesViewModel(candidates: words, currentPage: 0, totalPageCount: 3, showAnnotationPopover: true)
        viewModel.selected = words.first
        viewModel.systemAnnotations = [words.first!.word: String(repeating: "これはシステム辞書の注釈です。", count: 20)]
        viewModel.maxWidth = 1000
        viewModel.displayCandidatesHorizontally = true
        return viewModel
    }

    private static func pageViewModelLeftPopover() -> CandidatesViewModel {
        let viewModel = CandidatesViewModel(candidates: words, currentPage: 0, totalPageCount: 3, showAnnotationPopover: true)
        viewModel.selected = words.first
        viewModel.systemAnnotations = [words.first!.word: String(repeating: "これはシステム辞書の注釈です。", count: 20)]
        viewModel.maxWidth = 1
        viewModel.displayCandidatesHorizontally = true
        return viewModel
    }

    private static func pageWithoutPopoverViewModel() -> CandidatesViewModel {
        let viewModel = CandidatesViewModel(candidates: words, currentPage: 0, totalPageCount: 3, showAnnotationPopover: false)
        viewModel.selected = words.first
        viewModel.systemAnnotations = [words.first!.word: String(repeating: "これはシステム辞書の注釈です。", count: 10)]
        viewModel.displayCandidatesHorizontally = true
        return viewModel
    }

    private static func inlineViewModel() -> CandidatesViewModel {
        let viewModel = CandidatesViewModel(candidates: words, currentPage: 0, totalPageCount: 3, showAnnotationPopover: true)
        viewModel.candidates = .inline
        viewModel.selected = words.first
        viewModel.systemAnnotations = [words.first!.word: String(repeating: "これはシステム辞書の注釈です。", count: 10)]
        viewModel.displayCandidatesHorizontally = true
        return viewModel
    }

    private static func fontSize19ViewModel() -> CandidatesViewModel {
        let viewModel = CandidatesViewModel(candidates: words, currentPage: 0, totalPageCount: 3, showAnnotationPopover: true, candidatesFontSize: CGFloat(19), annotationFontSize: CGFloat(19))
        viewModel.selected = words.first
        viewModel.systemAnnotations = [words.first!.word: String(repeating: "これはシステム辞書の注釈です。", count: 20)]
        viewModel.maxWidth = 1000
        viewModel.displayCandidatesHorizontally = true
        return viewModel
    }

    static var previews: some View {
        CandidatesView(candidates: pageViewModel())
            .background(Color.cyan)
            .previewDisplayName("パネル表示 (横)")
        CandidatesView(candidates: pageViewModelLeftPopover())
            .background(Color.cyan)
            .previewDisplayName("パネル表示 (横、注釈上)")
        CandidatesView(candidates: pageWithoutPopoverViewModel())
            .previewDisplayName("パネル表示 (横、注釈なし)")
        CandidatesView(candidates: inlineViewModel())
            .previewDisplayName("インライン表示")
        CandidatesView(candidates: fontSize19ViewModel())
            .background(Color.cyan)
            .previewDisplayName("フォントサイズ19 (横)")
    }
}
