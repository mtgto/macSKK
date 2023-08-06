// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// 変換候補ビュー
/// とりあえず10件ずつ縦に表示、スペースで次の10件が表示される
struct CandidatesView: View {
    @StateObject var candidates: CandidatesViewModel
    /// 一行の高さ
    static let lineHeight: CGFloat = 20
    static let footerHeight: CGFloat = 20
    private let font: Font = .body

    var body: some View {
        VStack(spacing: 0) {
            List(Array(candidates.candidates.words.enumerated()), id: \.element, selection: $candidates.selected) { index, candidate in
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
                .popover(
                    isPresented: .constant(candidate == candidates.selected && (candidate.annotation != nil || candidates.systemAnnotations[candidate] != nil)),
                    arrowEdge: .trailing
                ) {
                    AnnotationView(annotation: .constant(candidate.annotation), systemAnnotation: $candidates.systemAnnotations[candidate])
                }
            }
            .listStyle(.plain)
            .environment(\.defaultMinListRowHeight, Self.lineHeight)  // Listの行の上下の余白を削除
            .scrollDisabled(true)
            .frame(width: minWidth(), height: CGFloat(candidates.candidates.words.count) * Self.lineHeight)
            HStack(alignment: .center, spacing: 0) {
                Spacer()
                Text("\(candidates.candidates.currentPage + 1) / \(candidates.candidates.totalPageCount)")
                    .padding(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 4))
            }
            .frame(width: minWidth(), height: Self.footerHeight)
        }
    }

    // 最長のテキストを表示するために必要なビューのサイズを返す
    private func minWidth() -> CGFloat {
        let width = candidates.candidates.words.map { candidate -> CGFloat in
            let size = candidate.word.boundingRect(
                with: CGSize(width: .greatestFiniteMagnitude, height: Self.lineHeight),
                options: .usesLineFragmentOrigin,
                attributes: [.font: NSFont.preferredFont(forTextStyle: .body)])
            // 未解決の余白(8px) + 添字(16px) + 余白(4px) + テキスト + 余白(4px) + 未解決の余白(22px)
            // @see https://forums.swift.org/t/swiftui-list-horizontal-insets-macos/52985/5
            return 16 + 4 + size.width + 4 + 22
        }.max()
        return width ?? 0
    }
}

struct CandidatesView_Previews: PreviewProvider {
    private static let words: [Word] = (1..<9).map {
        Word(String(repeating: "例文\($0)", count: $0), annotation: "注釈\($0)")
    }

    static var previews: some View {
        let viewModel = CandidatesViewModel(candidates: words, currentPage: 0, totalPageCount: 3)
        viewModel.selected = words.first
        viewModel.systemAnnotations = [words.first!: String(repeating: "これはシステム辞書の注釈です。", count: 10)]
        return CandidatesView(candidates: viewModel)
    }
}
