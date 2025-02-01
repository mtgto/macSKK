// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import Foundation
import AppKit

/// 現在表示されている変換候補の情報
enum CurrentCandidates {
    /// インラインで選択されている変換候補
    case inline
    /// パネルで複数の変換候補を表示
    ///
    /// - Parameters:
    ///   - words: 現在表示されている変換候補
    ///   - currentPage: wordsが全体の変換候補表示の何ページ目かという数値 (0オリジン)
    ///   - totalPageCount: 全体の変換候補表示の最大ページ数
    case panel(words: [Candidate], /// 現在表示されている変換候補
               currentPage: Int,
               totalPageCount: Int)
}

@MainActor
final class CandidatesViewModel: ObservableObject {
    @Published var candidates: CurrentCandidates
    @Published var selected: Candidate?
    /// 二回連続で同じ値がセットされた (マウスで選択されたとき)
    @Published var doubleSelected: Candidate?
    /// 選択中の変換候補のシステム辞書での注釈。キーは変換候補
    @Published var systemAnnotations = Dictionary<Word.Word, String>()
    @Published var popoverIsPresented: Bool = false
    @Published var selectedIndex: Int?
    @Published var selectedSystemAnnotation: String?
    @Published var selectedAnnotations: [Annotation] = []
    /// パネル表示時に注釈を表示するかどうか
    @Published var showAnnotationPopover: Bool
    /// 変換候補のフォントサイズ
    @Published var candidatesFontSize: CGFloat
    /// 注釈のフォントサイズ
    @Published var annotationFontSize: CGFloat
    /// 表示座標から右方向に取れる最大の幅。負数のときは不明なとき
    @Published var maxWidth: CGFloat = -1
    /// 最長のテキストを表示するために必要なビューの横幅。パネル表示のときは注釈部分は除いたリスト部分の幅。
    @Published var minWidth: CGFloat = 0
    /// 表示座標から上方向に取れる最大の幅。負数のときは不明なとき
    @Published var maxHeight: CGFloat = -1
    /// パネル表示時の注釈を左側に表示するかどうか
    @Published var displayPopoverInLeftOrTop: Bool = false
    /// 変換候補の一行の高さ
    var candidatesLineHeight: CGFloat {
        candidatesFontSize + 11
    }

    private var cancellables: Set<AnyCancellable> = []

    init(
        candidates: [Candidate],
        currentPage: Int,
        totalPageCount: Int,
        showAnnotationPopover: Bool,
        candidatesFontSize: CGFloat = 13,
        annotationFontSize: CGFloat = 13
    ) {
        self.candidates = .panel(words: candidates,
                                 currentPage: currentPage,
                                 totalPageCount: totalPageCount)
        self.showAnnotationPopover = showAnnotationPopover
        self.candidatesFontSize = candidatesFontSize
        self.annotationFontSize = annotationFontSize
        if let first = candidates.first {
            self.selected = first
        }

        $selected.combineLatest($systemAnnotations).sink { [weak self] (selected, systemAnnotations) in
            if let selected, let self {
                self.selectedAnnotations = selected.annotations
                if case let .panel(words, _, _) = self.candidates {
                    self.selectedIndex = words.firstIndex(of: selected)
                } else {
                    self.selectedIndex = nil
                }
                self.selectedSystemAnnotation = systemAnnotations[selected.word]
                self.popoverIsPresented = self.showAnnotationPopover && (self.selectedAnnotations != [] || self.selectedSystemAnnotation != nil)
            }
        }
        .store(in: &cancellables)

        $candidates.combineLatest(Global.candidateListDirection).map { candidates, listDirection in
            if case let .panel(words, _, _) = candidates {
                switch listDirection {
                case .vertical:
                    let listWidth = words.map { candidate -> CGFloat in
                        let size = candidate.word.boundingRect(
                            with: CGSize(width: .greatestFiniteMagnitude, height: self.candidatesLineHeight),
                            options: .usesLineFragmentOrigin,
                            attributes: [.font: NSFont.preferredFont(forTextStyle: .body)])
                        // 未解決の余白(8px) + 添字(16px) + 余白(4px) + テキスト + 余白(4px) + 未解決の余白(22px)
                        // @see https://forums.swift.org/t/swiftui-list-horizontal-insets-macos/52985/5
                        return 16 + 4 + size.width + 4 + 22
                    }.max() ?? 0
                    return listWidth
                case .horizontal:
                    let listWidth = words.reduce(0) { last, candidate -> CGFloat in
                        let size = candidate.word.boundingRect(
                            with: CGSize(width: .greatestFiniteMagnitude, height: self.candidatesLineHeight),
                            options: .usesLineFragmentOrigin,
                            attributes: [.font: NSFont.preferredFont(forTextStyle: .body)])
                        // 添字(16px) + 余白(4px) +  テキスト + 余白(8px)
                        return 16 + 4 + size.width + 8 + last
                    }
                    // + ページカウント(64px)
                    return listWidth + 64
                }
            } else {
                return 300
            }
        }
        .assign(to: &$minWidth)

        $maxWidth.combineLatest($minWidth, $showAnnotationPopover, Global.candidateListDirection)
            .filter { maxWidth, _, _, listDirection in
                // maxWidthが0未満のときはまだスクリーンサイズがわかっていない
                listDirection == .vertical && maxWidth >= 0
            }
            .map { maxWidth, minWidth, showAnnotationPopover, _ in
                showAnnotationPopover &&
                minWidth + CandidatesView.annotationPopupWidth + CandidatesView.annotationMargin >= maxWidth
            }
            .assign(to: &$displayPopoverInLeftOrTop)
        
        $maxHeight.combineLatest($showAnnotationPopover, Global.candidateListDirection)
            .filter { maxHeight, _, listDirection in
                return listDirection == .horizontal && maxHeight >= 0
            }
            .map { maxHeight, showAnnotationPopover, _ in
                showAnnotationPopover &&
                self.candidatesLineHeight + HorizontalCandidatesView.annotationPopupHeight + CandidatesView.annotationMargin >= maxHeight
            }
            .assign(to: &$displayPopoverInLeftOrTop)
    }
}
