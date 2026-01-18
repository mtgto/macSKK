// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import AppKit

// 現在表示されている補完候補の情報
enum CurrentCompletion {
    case yomi(String)
    case candidates([Candidate])
}

@MainActor
final class CompletionViewModel: ObservableObject {
    @Published var completion: CurrentCompletion
    @Published var candidatesViewModel: CandidatesViewModel
    private var cancellables: Set<AnyCancellable> = []
    var padding: CGFloat {
        if case .yomi = completion {
            2
        } else {
            0
        }
    }

    init(completion: CurrentCompletion, candidatesFontSize: Int, annotationFontSize: Int) {
        self.completion = completion
        let candidates: [Candidate]
        if case .candidates(let words) = completion {
            candidates = words
        } else {
            candidates = []
        }
        self.candidatesViewModel = CandidatesViewModel(
            candidates: candidates,
            currentPage: 0,
            totalPageCount: 1,
            showAnnotationPopover: false,
            nsCandidatesFont: NSFont.systemFont(ofSize: CGFloat(candidatesFontSize)),
            candidatesMarkerFont: .system(size: CGFloat(candidatesFontSize) * 0.9),
            annotationFont: .system(size: CGFloat(annotationFontSize)),
            showPage: false,
        )

        $completion.dropFirst().sink { [weak self] completion in
            guard let self else { return }
            if case .candidates(let words) = completion {
                logger.debug("補完候補が更新されました")
                self.candidatesViewModel.candidates = .panel(words: words, currentPage: 0, totalPageCount: 1)
            } else {
                self.candidatesViewModel.candidates = .inline
            }
        }.store(in: &cancellables)
    }
}
