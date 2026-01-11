// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct VerticalCandidatesView: View {
    @ObservedObject var candidates: CandidatesViewModel
    
    let words: [Candidate]
    let currentPage: Int
    let totalPageCount: Int

    var body: some View {
        HStack(alignment: .top, spacing: CandidatesView.annotationMarginLeftRight) {
            if candidates.displayPopoverInLeftOrTop {
                if candidates.popoverIsPresented {
                    AnnotationView(
                        annotations: $candidates.selectedAnnotations,
                        systemAnnotation: $candidates.selectedSystemAnnotation,
                        font: candidates.annotationFont
                    )
                    .padding(EdgeInsets(top: 16, leading: 12, bottom: 16, trailing: 8))
                    .frame(width: CandidatesView.annotationPopupWidth, alignment: .topLeading)
                    .frame(maxHeight: max(200, CGFloat(words.count) * candidates.candidatesLineHeight + CandidatesView.footerHeight))
                    .fixedSize(horizontal: false, vertical: /*@START_MENU_TOKEN@*/true/*@END_MENU_TOKEN@*/)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .opacity(0.9)
                } else {
                    Spacer(minLength: CandidatesView.annotationPopupWidth)
                }
            }
            VStack(spacing: 0) {
                List(Array(words.enumerated()), id: \.element, selection: $candidates.selected) { index, candidate in
                    HStack(alignment: .firstTextBaseline) {
                        Text(String(Global.selectCandidateKeys[index]).uppercased())
                            .font(candidates.candidatesMarkerFont)
                            // 目立たないようにする
                            .foregroundStyle(candidates.selected == candidate ? Color(NSColor.selectedMenuItemTextColor.withAlphaComponent(0.8)) : Color(NSColor.secondaryLabelColor))
                            .padding(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 0))
                            .frame(width: 16)
                        Text(candidate.word)
//                            .font(.system(size: candidates.candidatesFontSize))
                            .font(candidates.candidatesFont)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 4))
                        Spacer()  // popoverをListの右に表示するために余白を入れる
                    }
                    .listRowInsets(EdgeInsets())
                    .frame(height: candidates.candidatesLineHeight)
                    // .border(Color.red) // Listの謎のInsetのデバッグ時に使用する
                    .contentShape(Rectangle())
                    .listRowBackground(candidate == candidates.selected ? candidates.selectedCandidatesBackgroundColor : Color.clear)
                }
                .listStyle(.plain)
                // Listの行の上下の余白を削除
                .environment(\.defaultMinListRowHeight, candidates.candidatesLineHeight)
                .scrollDisabled(true)
                .frame(width: candidates.minWidth, height: CGFloat(words.count) * candidates.candidatesLineHeight)
                // 背景色を設定してないときにhiddenにしちゃうと背景が抜けちゃうので、設定されているときだけhiddenにする
                .scrollContentBackground(candidates.candidatesBackgroundColor != nil ? .hidden : .automatic)
                .tint(Color.red)
                if candidates.showPage {
                    HStack(alignment: .center, spacing: 0) {
                        Spacer()
                        Text("\(currentPage + 1) / \(totalPageCount)")
                            .foregroundStyle(Color(NSColor.secondaryLabelColor))
                            .padding(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 4))
                    }
                    .frame(width: candidates.minWidth, height: CandidatesView.footerHeight)
                    .optionalBackground(candidates.candidatesBackgroundColor)
                }
            }
            .optionalBackground(candidates.candidatesBackgroundColor)
            if candidates.popoverIsPresented && !candidates.displayPopoverInLeftOrTop {
                AnnotationView(
                    annotations: $candidates.selectedAnnotations,
                    systemAnnotation: $candidates.selectedSystemAnnotation,
                    font: candidates.annotationFont
                )
                .padding(EdgeInsets(top: 16, leading: 28, bottom: 16, trailing: 4))
                .frame(width: CandidatesView.annotationPopupWidth, alignment: .topLeading)
                .frame(maxHeight: max(200, CGFloat(words.count) * candidates.candidatesLineHeight + CandidatesView.footerHeight))
                .fixedSize(horizontal: false, vertical: /*@START_MENU_TOKEN@*/true/*@END_MENU_TOKEN@*/)
                .optionalBackground(candidates.annotationBackgroundColor, cornerRadius: 10)
                .opacity(0.9)
            }
        }
        .frame(maxHeight: 300, alignment: .topLeading)
        .background(Color.clear)
    }
}

struct VerticalCandidatesView_Previews: PreviewProvider {
    private static let words: [Candidate] = (1...9).map {
        Candidate(String(repeating: "例文\($0)", count: $0),
                  annotations: [Annotation(dictId: "SKK-JISYO.L", text: "注釈\($0)")])
    }

    private static func pageViewModel() -> CandidatesViewModel {
        let viewModel = CandidatesViewModel(candidates: words, currentPage: 0, totalPageCount: 3, showAnnotationPopover: true)
        viewModel.selected = words.first
        viewModel.systemAnnotations = [words.first!.word: String(repeating: "これはシステム辞書の注釈です。", count: 20)]
        viewModel.maxWidth = 1000
        return viewModel
    }

    private static func pageViewModelLeftPopover() -> CandidatesViewModel {
        let viewModel = CandidatesViewModel(candidates: words, currentPage: 0, totalPageCount: 3, showAnnotationPopover: true)
        viewModel.selected = words.first
        viewModel.systemAnnotations = [words.first!.word: String(repeating: "これはシステム辞書の注釈です。", count: 20)]
        viewModel.maxWidth = 1
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
        let viewModel = CandidatesViewModel(candidates: words, currentPage: 0, totalPageCount: 3, showAnnotationPopover: true, candidatesFontSize: CGFloat(19), candidatesFont: .system(size: 19), annotationFontSize: CGFloat(19))
        viewModel.selected = words.first
        viewModel.systemAnnotations = [words.first!.word: String(repeating: "これはシステム辞書の注釈です。", count: 20)]
        viewModel.maxWidth = 1000
        return viewModel
    }

    private static func pageWithoutPageNumberViewModel() -> CandidatesViewModel {
        let viewModel = CandidatesViewModel(candidates: words, currentPage: 0, totalPageCount: 3, showAnnotationPopover: false)
        viewModel.showPage = false
        return viewModel
    }

    private static func customFontViewModel() -> CandidatesViewModel {
        let fontName = "凸版文久見出しゴシック"
        let fontSize: CGFloat = 16
        let font = Font(NSFont(name: fontName, size: fontSize)!)
        let candidatesMarkerFont = Font(NSFont(name: fontName, size: fontSize * 0.9)!)
        let viewModel = CandidatesViewModel(candidates: words, currentPage: 0, totalPageCount: 3, showAnnotationPopover: true, candidatesFontSize: fontSize, candidatesFont: font, candidatesMarkerFont: candidatesMarkerFont)
        viewModel.selected = words.first
        viewModel.systemAnnotations = [words.first!.word: String(repeating: "これはシステム辞書の注釈です。", count: 20)]
        viewModel.maxWidth = 1000
        return viewModel
    }

    private static func backgroundColorViewModel() -> CandidatesViewModel {
        let viewModel = CandidatesViewModel(candidates: words, currentPage: 0, totalPageCount: 3, showAnnotationPopover: true)
        viewModel.selected = words.first
        viewModel.systemAnnotations = [words.first!.word: String(repeating: "これはシステム辞書の注釈です。", count: 20)]
        viewModel.candidatesBackgroundColor = .green
        viewModel.annotationBackgroundColor = .blue
        viewModel.selectedCandidatesBackgroundColor = .purple
        return viewModel
    }

    static var previews: some View {
        VerticalCandidatesView(candidates: pageViewModel(), words: words, currentPage: 0, totalPageCount: 3)
            .background(Color.cyan)
            .previewDisplayName("パネル表示")
        VerticalCandidatesView(candidates: pageViewModelLeftPopover(), words: words, currentPage: 0, totalPageCount: 3)
            .background(Color.cyan)
            .previewDisplayName("パネル表示 (注釈左)")
        VerticalCandidatesView(candidates: pageWithoutPopoverViewModel(), words: words, currentPage: 0, totalPageCount: 3)
            .previewDisplayName("パネル表示 (注釈なし)")
        VerticalCandidatesView(candidates: inlineViewModel(), words: words, currentPage: 0, totalPageCount: 3)
            .previewDisplayName("インライン表示")
        VerticalCandidatesView(candidates: fontSize19ViewModel(), words: words, currentPage: 0, totalPageCount: 3)
            .background(Color.cyan)
            .previewDisplayName("フォントサイズ19")
        VerticalCandidatesView(candidates: customFontViewModel(), words: words, currentPage: 0, totalPageCount: 3)
            .background(Color.cyan)
            .previewDisplayName("カスタムフォント")
        VerticalCandidatesView(candidates: pageWithoutPageNumberViewModel(), words: words, currentPage: 0, totalPageCount: 3)
            .background(Color.cyan)
            .previewDisplayName("パネル表示 (ページなし)")
        VerticalCandidatesView(candidates: backgroundColorViewModel(), words: words, currentPage: 0, totalPageCount: 3)
            .background(Color.cyan)
            .previewDisplayName("背景色設定")
    }
}
