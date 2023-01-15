// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// 変換候補ビュー
/// とりあえず10件ずつ縦に表示、スペースで次の10件が表示される
struct CandidatesView: View {
    @ObservedObject var candidates: CandidatesViewModel

    var body: some View {
        VStack {
            List(candidates.candidates, id: \.self, selection: $candidates.selected) { word in
                Text(word.word)
            }
            .listRowInsets(.none)
            .environment(\.defaultMinListRowHeight, 20)
        }
    }
}

struct CandidatesView_Previews: PreviewProvider {
    private static let words: [Word] = (0..<10).map { Word("例文\($0)") }

    static var previews: some View {
        CandidatesView(candidates: CandidatesViewModel(candidates: words))
    }
}
