// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

// UserDefaultsのキー。camelCaseでの命名を採用しています。
struct UserDefaultsKeys {
    static let dictionaries = "dictionaries"
    static let directModeBundleIdentifiers = "directModeBundleIdentifiers"
    // 選択中のinputSourceID
    static let selectedInputSource = "selectedInputSource"
    static let showAnnotation = "showAnnotation"
    static let inlineCandidateCount = "inlineCandidateCount"
    static let workarounds = "workarounds"
    static let candidatesFontSize = "candidatesFontSize"
    static let annotationFontSize = "annotationFontSize"
    // SKK辞書サーバーへの接続設定
    static let skkservClient = "skkserv"
    // 選択候補パネルから決定するショートカットキー。
    // 初期値は "123456789"。
    static let selectCandidateKeys = "selectCandidateKeys"
    static let findCompletionFromAllDicts = "findCompletionFromAllDicts"
}
