// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// 変換候補ビュー
/// とりあえず10件ずつ縦に表示、スペースで次の10件が表示される
struct CandidatesView: View {
    @ObservedObject var candidates: CandidatesViewModel
    /// 一行の高さ
    static let lineHeight: CGFloat = 20
    static let footerHeight: CGFloat = 20
    private let font: Font = .body

    var body: some View {
        switch candidates.candidates {
        case .inline:
            AnnotationView(annotations: $candidates.selectedAnnotations, systemAnnotation: $candidates.selectedSystemAnnotation)
                .padding(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
                .frame(width: 300, height: 200)
        case let .panel(words, currentPage, totalPageCount):
            VStack(spacing: 0) {
                List(Array(words.enumerated()), id: \.element, selection: $candidates.selected) { index, candidate in
                    HStack {
                        Text("\(index + 1)")
                            .font(font)
                            .padding(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 0))
                            .frame(width: 16)
                        Text(candidate.word)
                            .font(font)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 4))
                        Spacer()  // popoverをListの右に表示するために余白を入れる
                    }
                    .listRowInsets(EdgeInsets())
                    .frame(height: Self.lineHeight)
                    // .border(Color.red) // Listの謎のInsetのデバッグ時に使用する
                    .contentShape(Rectangle())
                }
                .listStyle(.plain)
                .environment(\.defaultMinListRowHeight, Self.lineHeight)  // Listの行の上下の余白を削除
                .scrollDisabled(true)
                .frame(width: minWidth(), height: CGFloat(words.count) * Self.lineHeight)
                HStack(alignment: .center, spacing: 0) {
                    Spacer()
                    Text("\(currentPage + 1) / \(totalPageCount)")
                        .padding(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 4))
                }
                .frame(width: minWidth(), height: Self.footerHeight)
            }
            .popover(
                isPresented: $candidates.popoverIsPresented,
                attachmentAnchor: .rect(.rect(CGRect(x: 0,
                                                     y: CGFloat(candidates.selectedIndex ?? 0) * Self.lineHeight,
                                                     width: minWidth(),
                                                     height: Self.lineHeight))),
                arrowEdge: .trailing
            ) {
                AnnotationView(
                    annotations: $candidates.selectedAnnotations,
                    systemAnnotation: $candidates.selectedSystemAnnotation
                )
                .frame(width: 300, alignment: .topLeading)
                .padding()
            }
        }
    }

    // 最長のテキストを表示するために必要なビューのサイズを返す
    func minWidth() -> CGFloat {
        if case let .panel(words, _, _) = candidates.candidates {
            let width = words.map { candidate -> CGFloat in
                let size = candidate.word.boundingRect(
                    with: CGSize(width: .greatestFiniteMagnitude, height: Self.lineHeight),
                    options: .usesLineFragmentOrigin,
                    attributes: [.font: NSFont.preferredFont(forTextStyle: .body)])
                // 未解決の余白(8px) + 添字(16px) + 余白(4px) + テキスト + 余白(4px) + 未解決の余白(22px)
                // @see https://forums.swift.org/t/swiftui-list-horizontal-insets-macos/52985/5
                return 16 + 4 + size.width + 4 + 22
            }.max()
            return width ?? 0
        } else {
            return 300
        }
    }
}

struct CandidatesView_Previews: PreviewProvider {
    private static let words: [ReferredWord] = (1..<9).map {
        ReferredWord(yomi: "れいぶん", word: String(repeating: "例文\($0)", count: $0),
                     annotations: [Annotation(dictId: "SKK-JISYO.L", text: "注釈\($0)")])
    }

    private static func pageViewModel() -> CandidatesViewModel {
        let viewModel = CandidatesViewModel(candidates: words, currentPage: 0, totalPageCount: 3)
        viewModel.selected = words.first
        viewModel.systemAnnotations = [words.first!.word: String(repeating: "これはシステム辞書の注釈です。", count: 10)]
        return viewModel
    }

    private static func inlineViewModel() -> CandidatesViewModel {
        let viewModel = CandidatesViewModel(candidates: words, currentPage: 0, totalPageCount: 3)
        viewModel.candidates = .inline
        viewModel.selected = words.first
        viewModel.systemAnnotations = [words.first!.word: String(repeating: "これはシステム辞書の注釈です。", count: 10)]
        return viewModel
    }

    static var previews: some View {
        CandidatesView(candidates: pageViewModel())
            .previewDisplayName("パネル表示")
        CandidatesView(candidates: inlineViewModel())
            .previewDisplayName("インライン表示")
    }
}
