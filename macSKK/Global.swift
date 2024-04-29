// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Combine

/**
 * メインスレッドからのみ参照するグローバルな要素を保持する
 */
@MainActor struct Global {
    static let shared = Global()
    static let privateMode = CurrentValueSubject<Bool, Never>(false)
    // 直接入力するアプリケーションのBundleIdentifierの集合のコピー。
    // マスターはSettingsViewModelがもっているが、InputControllerからAppが参照できないのでグローバル変数にコピーしている。
    // FIXME: NotificationCenter経由で設定画面で変更したことを各InputControllerに通知するようにしてこの変数は消すかも。
    static let directModeBundleIdentifiers = CurrentValueSubject<[String], Never>([])
    // モード変更時に空白文字を一瞬追加するワークアラウンドを適用するBundle Identifierの集合
    static let insertBlankStringBundleIdentifiers = CurrentValueSubject<[String], Never>([])
    // 現在のモードを表示するパネル
    private let inputModePanel: InputModePanel
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

    static func showInputModePanel(at point: CGPoint, inputMode: InputMode, windowLevel: NSWindow.Level) {
        shared.inputModePanel.show(at: point,
                                   mode: inputMode,
                                   privateMode: Global.privateMode.value,
                                   windowLevel: windowLevel)
    }

    static func showCompletionPanel(at point: CGPoint, completion: String) {
        shared.completionPanel.viewModel.completion = completion
        shared.completionPanel.show(at: point)
    }

    static func hideCompletionPanel(_ sender: Any? = nil) {
        shared.completionPanel.orderOut(sender)
    }
}
