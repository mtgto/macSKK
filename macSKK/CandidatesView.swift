// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// 変換候補ビュー
/// とりあえず10件ずつ縦に表示、スペースで次の10件が表示される
struct CandidatesView: View {
    @ObservedObject var candidates: CandidatesViewModel

    var body: some View {
        // Listではスクロールが生じるためForEachを使用
        VStack(alignment: .leading, spacing: 0) {
            ForEach(candidates.candidates.indices, id: \.self) { index in
                let candidate = candidates.candidates[index]
                VStack {
                    Spacer()
                    HStack {
                        Text("\(index + 1)")
                            .padding(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 0))
                            .frame(width: 16)
                        Text(candidate.word)
                        Spacer()
                    }
                    .background(candidate == candidates.selected ? Color.accentColor : nil)
                    Spacer()
                }
                .frame(height: 20)
                .contentShape(Rectangle())
                .onTapGesture {
                    if candidates.selected == candidate {
                        candidates.doubleSelected = candidate
                    }
                    candidates.selected = candidate
                }
                .popover(
                    isPresented: .constant(candidate == candidates.selected && candidate.annotation != nil),
                    arrowEdge: .trailing
                ) {
                    Text(candidate.annotation!).padding()
                }
            }
        }
    }
}

struct CandidatesView_Previews: PreviewProvider {
    private static let words: [Word] = (1..<9).map {
        Word(String(repeating: "例文\($0)", count: $0), annotation: "注釈\($0)")
    }

    static var previews: some View {
        CandidatesView(candidates: CandidatesViewModel(candidates: words))
    }
}
