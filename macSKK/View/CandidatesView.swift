// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct VerticalCandidatesView: View {
    @ObservedObject var candidates: CandidatesViewModel
    
    let words: [Candidate]
    let currentPage: Int
    let totalPageCount: Int

    var body: some View {
        HStack(alignment: .top, spacing: CandidatesView.annotationMargin) {
            if candidates.displayPopoverInLeftOrTop {
                if candidates.popoverIsPresented {
                    AnnotationView(
                        annotations: $candidates.selectedAnnotations,
                        systemAnnotation: $candidates.selectedSystemAnnotation,
                        annotationFontSize: candidates.annotationFontSize
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
                    HStack {
                        Text(String(Global.selectCandidateKeys[index]).uppercased())
                        // 変換候補の90%のフォントサイズ
                            .font(.system(size: candidates.candidatesFontSize * 0.9))
                            .padding(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 0))
                            .frame(width: 16)
                        Text(candidate.word)
                            .font(.system(size: candidates.candidatesFontSize))
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 4))
                        Spacer()  // popoverをListの右に表示するために余白を入れる
                    }
                    .listRowInsets(EdgeInsets())
                    .frame(height: candidates.candidatesLineHeight)
                    // .border(Color.red) // Listの謎のInsetのデバッグ時に使用する
                    .contentShape(Rectangle())
                }
                .listStyle(.plain)
                // Listの行の上下の余白を削除
                .environment(\.defaultMinListRowHeight, candidates.candidatesLineHeight)
                .scrollDisabled(true)
                .frame(width: candidates.minWidth, height: CGFloat(words.count) * candidates.candidatesLineHeight)
                HStack(alignment: .center, spacing: 0) {
                    Spacer()
                    Text("\(currentPage + 1) / \(totalPageCount)")
                        .padding(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 4))
                }
                .frame(width: candidates.minWidth, height: CandidatesView.footerHeight)
                .background()
            }
            if candidates.popoverIsPresented && !candidates.displayPopoverInLeftOrTop {
                AnnotationView(
                    annotations: $candidates.selectedAnnotations,
                    systemAnnotation: $candidates.selectedSystemAnnotation,
                    annotationFontSize: candidates.annotationFontSize
                )
                .padding(EdgeInsets(top: 16, leading: 28, bottom: 16, trailing: 4))
                .frame(width: CandidatesView.annotationPopupWidth, alignment: .topLeading)
                .frame(maxHeight: max(200, CGFloat(words.count) * candidates.candidatesLineHeight + CandidatesView.footerHeight))
                .fixedSize(horizontal: false, vertical: /*@START_MENU_TOKEN@*/true/*@END_MENU_TOKEN@*/)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                .opacity(0.9)
            }
        }
        .frame(maxHeight: 300, alignment: .topLeading)
        .background(Color.clear)
    }
}

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
                    .frame(width: CandidatesView.annotationPopupWidth, alignment: .topLeading)
                    .frame(height: CandidatesView.annotationPopupHeightInHorzontalMode)
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
                .frame(width: CandidatesView.annotationPopupWidth, alignment: .topLeading)
                .frame(height: CandidatesView.annotationPopupHeightInHorzontalMode)
                .fixedSize(horizontal: false, vertical: /*@START_MENU_TOKEN@*/true/*@END_MENU_TOKEN@*/)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                .opacity(0.9)
            }
        }
        .background(Color.clear)
    }
}

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
        let viewModel = CandidatesViewModel(candidates: words, currentPage: 0, totalPageCount: 3, showAnnotationPopover: true, candidatesFontSize: CGFloat(19), annotationFontSize: CGFloat(19))
        viewModel.selected = words.first
        viewModel.systemAnnotations = [words.first!.word: String(repeating: "これはシステム辞書の注釈です。", count: 20)]
        viewModel.maxWidth = 1000
        return viewModel
    }

    static var previews: some View {
        CandidatesView(candidates: pageViewModel())
            .background(Color.cyan)
            .previewDisplayName("パネル表示")
        CandidatesView(candidates: pageViewModelLeftPopover())
            .background(Color.cyan)
            .previewDisplayName("パネル表示 (注釈左)")
        CandidatesView(candidates: pageWithoutPopoverViewModel())
            .previewDisplayName("パネル表示 (注釈なし)")
        CandidatesView(candidates: inlineViewModel())
            .previewDisplayName("インライン表示")
        CandidatesView(candidates: fontSize19ViewModel())
            .background(Color.cyan)
            .previewDisplayName("フォントサイズ19")
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
