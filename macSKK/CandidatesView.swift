// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct CandidatesView: View {
    @Binding var words: [Word]

    var body: some View {
        List(words, id: \.self) { word in
            Text(word.word)
        }
    }
}

struct CandidatesView_Previews: PreviewProvider {
    static var previews: some View {
        CandidatesView(words: .constant([Word("例文")]))
    }
}
