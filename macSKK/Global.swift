// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import Foundation

/**
 * メインスレッドからのみ参照するグローバルな要素を保持する
 */
@MainActor struct Global {
    // static let shared = Global()
    static let privateMode = CurrentValueSubject<Bool, Never>(false)
    // 直接入力するアプリケーションのBundleIdentifierの集合のコピー。
    // マスターはSettingsViewModelがもっているが、InputControllerからAppが参照できないのでグローバル変数にコピーしている。
    // FIXME: NotificationCenter経由で設定画面で変更したことを各InputControllerに通知するようにしてこの変数は消すかも。
    static let directModeBundleIdentifiers = CurrentValueSubject<[String], Never>([])
    // モード変更時に空白文字を一瞬追加するワークアラウンドを適用するBundle Identifierの集合
    static let insertBlankStringBundleIdentifiers = CurrentValueSubject<[String], Never>([])
}
