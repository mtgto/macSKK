// SPDX-FileCopyrightText: 2022 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit

/**
 * ローマ字かな（記号も可）変換ルール
 */
struct Romaji: Equatable, Sendable {
    struct Moji: Equatable {
        init(firstRomaji: String, kana: String, katakana: String? = nil, hankaku: String? = nil, remain: String? = nil) {
            self.firstRomaji = firstRomaji
            self.kana = kana
            self.katakana = katakana
            self.hankaku = hankaku
            self.remain = remain
        }

        /**
         * SKK辞書で表現されるローマ字
         *
         * - TODO: EmacsのSKK基準で実装する。とりあえず不明なものは空文字列にしている。
         */
        let firstRomaji: String
        /// ひらがなモードでの表記
        let kana: String
        /// カタカナモードでの表記
        let katakana: String?
        /// 半角カナモードでの表記
        let hankaku: String?
        /**
         * 未確定文字列に残すローマ字
         *
         * 例えば "kk" と入力したら "っ" を確定して "k" を未確定入力に残す
         */
        let remain: String?

        func string(for mode: InputMode) -> String {
            switch mode {
            case .hiragana:
                return kana
            case .katakana:
                return katakana ?? kana.toKatakana()
            case .hankaku:
                return hankaku ?? kana.toKatakana().toHankaku()
            case .direct:  // Abbrevモード用
                return firstRomaji
            default:
                fatalError("Called Romaji.Moji.string from wrong mode \(mode)")
            }
        }
    }

    /**
     * 入力されたローマ字をMojiに変換した結果。Romaji.convertの返値として利用する。
     *
     * 例
     * - aを入力: input: "", kakutei: "あ"
     * - bを入力: input: "b", kakutei: nil
     * - bbと入力: input: "b", kakutei: "っ"
     * - dgと入力: input: "g", kakutei: nil (dのあとに続けられないgを入力したのでdは無効となった)
     */
    struct ConvertedMoji: Equatable {
        /// 未確定で残っているローマ字
        let input: String
        /// 確定した文字。
        let kakutei: Moji?
    }

    static let n = Moji(firstRomaji: "n", kana: "ん")

    enum RomajiError: Error {
        /// 不正な設定
        case invalid
    }

    /// ローマ字かな変換テーブル
    let table: [String: Moji]

    /**
     * シフトキーで別の記号に変換される文字についてシフトを押しながら押したとするための対応表。
     * 日本語配列で "+" (シフト + ;) を入力したときに "+" ではなく シフトを押しながら;として押したと扱うために使用する。
     * AZIKで余っているキーに処理を割り当てたいときなどに使用する。
     */
    let lowercaseMap: [String: String]

    /**
     * 未確定文字列のままになることができる文字列の集合。
     *
     * 例えば ["k", "ky", "t"] となっている場合、kt と連続して入力したときには
     * このあとにどんな文字列を入力してもローマ字変換が確定しないためkは捨てられて未確定文字列はtとなる。
     * 現在入力中の未確定文字列がこの集合にないときは最後の未確定文字列だけを残すために利用する。
     */
    let undecidedInputs: Set<String>

    /// 設定がまったくないか
    var isEmpty: Bool {
        table.isEmpty && lowercaseMap.isEmpty
    }

    init(contentsOf url: URL) throws {
        try self.init(source: try String(contentsOf: url, encoding: .utf8))
    }

    init(source: String) throws {
        var table: [String: Moji] = [:]
        var undecidedInputs: Set<String> = []
        var lowercaseMap: [String: String] = [:]
        var error: RomajiError? = nil
        var lineNumber = 0
        source.enumerateLines { line, stop in
            lineNumber += 1
            // #で始まる行はコメント行
            if line.starts(with: "#") || line.isEmpty {
                return
            }
            // TODO: 正規表現などで一要素目がキーボードから直接入力できるASCII文字であることを検査する
            let elements = line.split(separator: ",", maxSplits: 5).map {
                $0.replacingOccurrences(of: "&comma;", with: ",").replacingOccurrences(of: "&sharp;", with: "#")
            }
            if elements.count < 2 || elements.contains(where: { $0.isEmpty }) {
                logger.error("ローマ字変換定義ファイルの \(lineNumber) 行目の記述が壊れているため読み込みできません")
                error = RomajiError.invalid
                stop = true
                return
            }
            // 第二要素だけがあり、第二要素が "<shift>" + 一文字 のような形式の場合、lowercaseMapの設定として扱う
            if elements.count == 2 && elements[1].hasPrefix("<shift>") && elements[1].count == 8 {
                let converted = String(elements[1].dropFirst(7))
                // 簡単な無限ループになってないかの検査
                guard elements[0] != converted else {
                    logger.error("ローマ字変換定義ファイルの \(lineNumber) 行目のlowercaseMap記述が壊れているため読み込みできません")
                    error = RomajiError.invalid
                    stop = true
                    return
                }
                lowercaseMap[elements[0]] = converted
                return
            }
            let firstRomaji = elements.count == 5 ? elements[4] : String(Self.firstRomajis[elements[1].first!] ?? elements[0].first!)
            let hiragana = elements[1]
            let katakana = elements.count > 2 ? elements[2] : nil
            let hankaku = elements.count > 3 ? elements[3] : nil
            let remain = elements.count > 4 ? elements[4] : nil
            table[elements[0]] = Moji(firstRomaji: firstRomaji,
                                      kana: hiragana,
                                      katakana: katakana,
                                      hankaku: hankaku,
                                      remain: remain)
            if elements[0].count > 1 {
                for n in stride(from: elements[0].count - 1, to: 0, by: -1) {
                    let prefix = String(elements[0].prefix(n))
                    if undecidedInputs.contains(prefix) {
                        break
                    }
                    undecidedInputs.insert(prefix)
                }
            }
        }
        if let error {
            throw error
        }
        self.table = table
        self.undecidedInputs = undecidedInputs
        self.lowercaseMap = lowercaseMap
    }

    /**
     * ひらがなを受け取り、そのひらがなが送り仮名の一文字目となるときのSKK辞書での表記を返す。
     * https://ja.wikipedia.org/wiki/%E5%B9%B3%E4%BB%AE%E5%90%8D_(Unicode%E3%81%AE%E3%83%96%E3%83%AD%E3%83%83%E3%82%AF)
     * 小書きは通常送り仮名とならないキーについても辞書に登録したいニーズがあるかもしれないと考えて仮決定でおいている。
     * 仮決定は将来予告なしに変更するかもしれない (デファクトスタンダードがあることがわかったときなど)。
     *
     * 例:
     * - "あ" は "a", "い" は "i", "う" は "u"
     * - "こ" は "k"、"ぐ" は "g"
     * - "ざ", "ず", "ぜ", "ぞ" は "z", "じ" は "j"
     * - "ふ" は "h" ("f" ではない)
     * - "ん" は "n"
     * - "っ" は "t"
     * - "ゐ", "ゑ", "を" は "w"
     * - "ゔ" は "v" (仮決定)
     * - "ぁ", "ぃ", "ゃ", "ゅ", "ょ", "ゎ", "ゕ", "ゖ" などの特殊な小書き文字は "x" (仮決定. skkeletonと同じ)
     */
    static let firstRomajis: [Character: Character] = [
        "あ": "a",
        "い": "i",
        "う": "u",
        "え": "e",
        "お": "o",
        "か": "k",
        "き": "k",
        "く": "k",
        "け": "k",
        "こ": "k",
        "さ": "s",
        "し": "s",
        "す": "s",
        "せ": "s",
        "そ": "s",
        "た": "t",
        "ち": "t",
        "つ": "t",
        "て": "t",
        "と": "t",
        "な": "n",
        "に": "n",
        "ぬ": "n",
        "ね": "n",
        "の": "n",
        "は": "h",
        "ひ": "h",
        "ふ": "h",
        "へ": "h",
        "ほ": "h",
        "ま": "m",
        "み": "m",
        "む": "m",
        "め": "m",
        "も": "m",
        "や": "y",
        "ゆ": "y",
        "よ": "y",
        "ら": "r",
        "り": "r",
        "る": "r",
        "れ": "r",
        "ろ": "r",
        "わ": "w",
        "ゐ": "w",
        "ゑ": "w",
        "を": "w",
        "ん": "n",
        "が": "g",
        "ぎ": "g",
        "ぐ": "g",
        "げ": "g",
        "ご": "g",
        "ざ": "z",
        "じ": "j",
        "ず": "z",
        "ぜ": "z",
        "ぞ": "z",
        "だ": "d",
        "ぢ": "d",
        "づ": "d",
        "で": "d",
        "ど": "d",
        "ば": "b",
        "び": "b",
        "ぶ": "b",
        "べ": "b",
        "ぼ": "b",
        "ぱ": "p",
        "ぴ": "p",
        "ぷ": "p",
        "ぺ": "p",
        "ぽ": "p",
        "っ": "t",
        // 以下は仮決定。将来予告なしに変更する可能性あり。
        "ゔ": "v",
        "ぁ": "x",
        "ぃ": "x",
        "ぅ": "x",
        "ぇ": "x",
        "ぉ": "x",
        "ゃ": "x",
        "ゅ": "x",
        "ょ": "x",
        "ゎ": "x",
        "ゕ": "x",
        "ゖ": "x",
    ]

    /**
     * ローマ字文字列を受け取り、かな確定文字と残りのローマ字文字列を返す.
     *
     * - "ka" が入力されたら確定文字 "か" と残りのローマ字文字列 "" を返す
     * - "k" が入力されたら確定文字はnil, 残りのローマ字文字列 "k" を返す
     * - "n" が入力されたらこのあとに子音が続くまでは「ん」とならないので確定文字はnil
     * - "nk" のようにn + 子音が入力されたら確定文字 "ん" と残りのローマ字文字列 "k" を返す
     * - "nyk" のようにny + 子音が入力されたら"ny"を捨てて残りのローマ字文字列 "k" をinput引数としたときのconvertの結果を返す
     * - "kt" のように連続できない子音が連続したinputの場合は"k"を捨てて"t"をinput引数としたときのconvertの結果を返す
     * - "kya" のように確定した文字が複数の場合がありえる
     * - "aiueo" のように複数の確定が可能な場合は最初に確定できた文字だけを確定文字として返し、残りは(確定可能だが)inputとして返す
     * - ",", "." は引数 `comma`, `period` に従って変換する
     * - "1" のように非ローマ字文字列を受け取った場合は未定義とする (呼び出し側で処理する予定だけどここで処理するかも)
     */
    func convert(_ input: String, punctuation: Punctuation) -> ConvertedMoji {
        if input == "," && punctuation.comma != .default {
            if case .ten = punctuation.comma {
                return ConvertedMoji(input: "", kakutei: Romaji.Moji(firstRomaji: ",", kana: "、"))
            } else if case .comma = punctuation.comma {
                return ConvertedMoji(input: "", kakutei: Romaji.Moji(firstRomaji: ",", kana: "，"))
            } else {
                fatalError()
            }
        } else if input == "." && punctuation.period != .default {
            if case .maru = punctuation.period {
                return ConvertedMoji(input: "", kakutei: Romaji.Moji(firstRomaji: ".", kana: "。"))
            } else if case .period = punctuation.period {
                return ConvertedMoji(input: "", kakutei: Romaji.Moji(firstRomaji: ".", kana: "．"))
            } else {
                fatalError()
            }
        } else if undecidedInputs.contains(input) {
            return ConvertedMoji(input: input, kakutei: nil)
        } else if let moji = table[input] {
            return ConvertedMoji(input: moji.remain ?? "", kakutei: moji)
        } else if input.count == 2, let first = input.first, let converted = table[String(first)] {
            return ConvertedMoji(input: String(input.dropFirst()), kakutei: converted)
        } else if input.count > 1, let last = input.last {
            return convert(String(last), punctuation: punctuation)
        }
        return ConvertedMoji(input: input, kakutei: nil)
    }

    /**
     * キー入力を別のキーとして扱う設定があれば変換する
     *
     * 変換後もNSEvent.keyCodeは変更されないので、もし非印字キー (Backspace、英数キーなど) として扱うキーに変換したい場合は
     * lowercaseMapの値の型を変更すること。
     *
     * 今はシフトキーが押されているときのみに対応する
     * https://github.com/mtgto/macSKK/issues/225
     *
     * > Note: charactersIgnoringModifiersは本来のIMKInputController#handleではシフトキーで変わる記号の場合
     *         `characters = "<"`, `charactersIgnoringModifiers = ","` のように異なります。
     *         しかしcharactersが記号の場合のcharactersIgnoringModifiersをシフトキーなしのときの文字として
     *         記述する設定方法を用意してないので、暫定としてcharactersと同様の値を設定します。
     */
    func convertKeyEvent(_ event: NSEvent) -> NSEvent? {
        // シフトキーが押されてなければ無視する
        if !event.modifierFlags.contains(.shift) {
            return nil
        }
        guard let characters = event.characters else {
            return nil
        }
        if let mapped = lowercaseMap[characters] {
            return NSEvent.keyEvent(with: event.type,
                                    location: event.locationInWindow,
                                    modifierFlags: event.modifierFlags,
                                    timestamp: event.timestamp,
                                    windowNumber: event.windowNumber,
                                    context: nil,
                                    characters: mapped,
                                    charactersIgnoringModifiers: mapped,
                                    isARepeat: event.isARepeat,
                                    keyCode: event.keyCode)
        }
        return nil
    }

    /**
     * 入力された文字列を受け取り、ローマ字かな変換ルールの入力として正しい接頭辞または全部かどうかを判定する。
     *
     * 1. Option, Command, Controlが押されている場合は常にfalseを返す
     * 2. アルファベットかそれ以外かで判定する
     * 3. ローマ字かな変換ルールに登録されているのがひらがなかどうかで判定する
     *
     * デフォルトのローマ字かな変換ルールでの例:
     *
     * input | modifierFlags | treatAsAlphabet |  結果  | 補足
     * ----- | ------------- | --------------- | ----- | ----
     * "a"   | `[]`          | false           | true  | "a" の全体なので
     * "a"   | `[.shift]`    | false           | true  | アルファベットの場合シフトキーが押されていてもよい
     * "a"   | `[.option]`   | false           | false | Optionキーが押されている場合は常にfalse
     * "k"   | `[]`          | false           | true  | "ka" の一部
     * "ky"  | `[]`          | false           | true  | "kya" の一部
     * "q"   | `[]`          | false           | false | "q" で始まるローマ字はない
     * "."   | `[]`          | false           | true  | ".,。" の全体なのでtrue
     * "."   | `[.shift]`    | false           | false | アルファベット以外でシフトキーが押されている場合は別のキーとして扱う
     * "."   | `[.shift]`    | true            | true  | 記号だが実質アルファベットとして見做す
     *
     * - Parameters
     *   - input: IMKInputController.handle の引数NSEventのcharacterIgnoringModifiers
     *   - modifierFlags: 修飾キー
     *   - treatAsAlphabet: 実質アルファベットとして見做すかどうか。Romaji.convertKeyEventで変換された場合。
     */
    func isPrefix(_ input: String, modifierFlags: NSEvent.ModifierFlags, treatAsAlphabet: Bool) -> Bool {
        if !modifierFlags.isDisjoint(with: [.option, .command, .control]) {
            return false
        } else if let romaji = table[input] {
            return romaji.kana.isHiragana || input.isAlphabet || !modifierFlags.contains(.shift) || treatAsAlphabet
        } else if undecidedInputs.contains(input){
            return input.isAlphabet || !modifierFlags.contains(.shift) || treatAsAlphabet
        }
        return false
    }
}
