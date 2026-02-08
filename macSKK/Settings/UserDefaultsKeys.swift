// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/**
 * UserDefaultsのキー。camelCaseでの命名を採用しています。
 * キーを追加するときは macSKKApp#setupUserDefaults で初期設定を設定するようにしてください。
 */
struct UserDefaultsKeys {
    static let dictionaries = "dictionaries"
    static let directModeBundleIdentifiers = "directModeBundleIdentifiers"
    // 選択中のinputSourceID
    static let selectedInputSource = "selectedInputSource"
    static let showAnnotation = "showAnnotation"
    static let inlineCandidateCount = "inlineCandidateCount"
    static let workarounds = "workarounds"
    /// 変換候補のフォントファミリー名
    static let candidatesFontFamily = "candidatesFontFamily"
    /// 変換候補のフォントサイズ
    static let candidatesFontSize = "candidatesFontSize"
    /// 変換候補の背景色
    static let candidatesBackgroundColor = "candidatesBackgroundColor"
    /// 変換候補の背景色を上書きするか
    static let overridesCandidatesBackgroundColor = "overridesCandidatesBackgroundColor"
    /// 注釈のフォントファミリー名
    static let annotationFontFamily = "annotationFontFamily"
    /// 注釈のフォントサイズ
    static let annotationFontSize = "annotationFontSize"
    /// 注釈の背景色
    static let annotationBackgroundColor = "annotationBackgroundColor"
    /// 注釈の背景色を上書きするか
    static let overridesAnnotationBackgroundColor = "overridesAnnotationBackgroundColor"
    // SKK辞書サーバーへの接続設定
    static let skkservClient = "skkserv"
    // 選択候補パネルから決定するショートカットキー。
    // 初期値は "123456789"。
    static let selectCandidateKeys = "selectCandidateKeys"
    static let findCompletionFromAllDicts = "findCompletionFromAllDicts"
    // 選択中のキーバインド設定ID
    static let selectedKeyBindingSetId = "selectedKeyBindingSetId"
    // キーバインド設定の配列
    static let keyBindingSets = "keyBindingSets"
    // Enterキーで変換候補の確定 + 改行も行う
    static let enterNewLine = "enterNewLine"
    // 補完を表示するか
    static let showCompletion = "showCompletion"
    // 変換候補の補完を表示するかどうか。例えば "ほか" まで入力したときに "補完" と表示するか
    static let showCandidateForCompletion = "showCandidateForCompletion"
    // 注釈に使用するシステム辞書のID。SystemDict.Kindで定義。
    static let systemDict = "systemDict"
    // 変換候補選択中のバックスペースの挙動
    static let selectingBackspace = "selectingBackspace"
    // カンマ、ピリオド入力時の句読点
    static let punctuation = "punctuation"
    static let privateMode = "privateMode"
    // プライベートモード時に変換候補にユーザー辞書を無視するかどうか
    static let ignoreUserDictInPrivateMode = "ignoreUserDictInPrivateMode"
    // 入力モードのモーダルを表示するかどうか
    static let showInputModePanel = "showInputModePanel"
    // 候補リストの表示方向
    static let candidateListDirection = "candidateListDirection"
    // 日時変換の変換後のリスト
    static let dateConversions = "dateConversions"
    // ピリオドで補完候補の最初の要素で確定するか
    static let fixedCompletionByPeriod = "fixedCompletionByPeriod"
    // qキーでカタカナで確定した場合に辞書に登録するか
    static let registerKatakana = "registerKatakana"
    // 選択中のローマ字かな変換ルールのID
    static let kanaRule = "kanaRule"
}
