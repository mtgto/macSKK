// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Combine

/**
 * メインスレッドからのみ参照するグローバルな要素を保持する
 */
@MainActor struct Global {
    static let shared = Global()
    /// 利用可能な辞書の集合
    static var dictionary: UserDict!
    /// skkserv辞書
    static var skkservDict: SKKServDict? = nil
    static let privateMode = CurrentValueSubject<Bool, Never>(false)
    // 直接入力するアプリケーションのBundleIdentifierの集合のコピー。
    // マスターはSettingsViewModelがもっているが、InputControllerからAppが参照できないのでグローバル変数にコピーしている。
    // FIXME: NotificationCenter経由で設定画面で変更したことを各InputControllerに通知するようにしてこの変数は消すかも。
    static let directModeBundleIdentifiers = CurrentValueSubject<[String], Never>([])
    // モード変更時に空白文字を一瞬追加するワークアラウンドを適用するBundle Identifierの集合
    static let insertBlankStringBundleIdentifiers = CurrentValueSubject<[String], Never>([])
    /// 現在のローマ字かな変換ルール
    static var kanaRule: Romaji!
    /// デフォルトでもってるローマ字かな変換ルール
    static var defaultKanaRule: Romaji!
    // 現在のモードを表示するパネル
    private let inputModePanel: InputModePanel
    // 変換候補を表示するパネル
    private let candidatesPanel: CandidatesPanel
    // 補完候補を表示するパネル
    private let completionPanel: CompletionPanel

    init() {
        inputModePanel = InputModePanel()
        candidatesPanel = CandidatesPanel(
            showAnnotationPopover: UserDefaults.standard.bool(forKey: UserDefaultsKeys.showAnnotation),
            candidatesFontSize: UserDefaults.standard.integer(forKey: UserDefaultsKeys.candidatesFontSize),
            annotationFontSize: UserDefaults.standard.integer(forKey: UserDefaultsKeys.annotationFontSize)
        )
        completionPanel = CompletionPanel()
    }

    static var inputModePanel: InputModePanel {
        shared.inputModePanel
    }

    static var completionPanel: CompletionPanel {
        shared.completionPanel
    }

    static var candidatesPanel: CandidatesPanel {
        shared.candidatesPanel
    }
}
