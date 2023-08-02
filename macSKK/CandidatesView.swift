// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// 変換候補ビュー
/// とりあえず10件ずつ縦に表示、スペースで次の10件が表示される
struct CandidatesView: View {
    @ObservedObject var candidates: CandidatesViewModel
    /// 一行の高さ
    static let lineHeight: CGFloat = 20
    @State private var selectedIndex: Int = 0

    var body: some View {
        // Listではスクロールが生じるためForEachを使用
        List(selection: $selectedIndex) {
            ForEach(candidates.candidates.indices, id: \.self) { index in
                let candidate = candidates.candidates[index]
                HStack {
                    Text("\(index + 1)")
                        .padding(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 0))
                        .frame(width: 16)
                    Text(candidate.word)
                        //.fixedSize(horizontal: true, vertical: false)
                        .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 4))
                }
                .listRowInsets(EdgeInsets())
                .frame(height: Self.lineHeight)
                .border(Color.red)
                .contentShape(Rectangle())
            }
            /* popoverだと候補ウィンドウを表示してないときに表示しづらいので別ビューにする予定
            .popover(
                isPresented: .constant(candidate == candidates.selected?.word && candidate.annotation != nil),
                arrowEdge: .trailing
            ) {
                VStack {
                    if let systemAnnotation = candidates.selected?.systemAnnotation {
                        Text(systemAnnotation)
                            .frame(idealWidth: 300, maxHeight: .infinity)
                            .padding()
                    } else {
                        Text(candidate.annotation!)
                            .frame(idealWidth: 300, maxHeight: .infinity)
                            .padding()
                    }
                }
            }
            */
        }
        .listStyle(.plain)
        .environment(\.defaultMinListRowHeight, Self.lineHeight)
        .scrollDisabled(true)
        .frame(width: 100, height: CGFloat(candidates.candidates.count) * Self.lineHeight)
        //.frame(width: 500, height: 200)
        .onChange(of: selectedIndex) { selectedIndex in
            let candidate = candidates.candidates[selectedIndex]
            if candidates.selected?.word == candidate {
                candidates.doubleSelected = candidate
            }
            candidates.selected = SelectedWord(word: candidate, systemAnnotation: nil)
        }
    }
}

struct CandidatesView_Previews: PreviewProvider {
    private static let words: [Word] = (1..<9).map {
        Word(String(repeating: "例文\($0)", count: $0), annotation: "注釈\($0)")
    }

    static var previews: some View {
        let viewModel = CandidatesViewModel(candidates: words)
        viewModel.selected = SelectedWord(word: words.first!, systemAnnotation: String(repeating: "これはシステム辞書の注釈です。", count: 10))
        return CandidatesView(candidates: viewModel)
    }
}
