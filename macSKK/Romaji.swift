// SPDX-FileCopyrightText: 2022 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

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

    /// ローマ字変換テーブル
    let table: [String: Moji]

    /**
     * 未確定文字列のままになることができる文字列の集合。
     *
     * 例えば ["k", "ky", "t"] となっている場合、kt と連続して入力したときには
     * このあとにどんな文字列を入力してもローマ字変換が確定しないためkは捨てられて未確定文字列はtとなる。
     * 現在入力中の未確定文字列がこの集合にないときは最後の未確定文字列だけを残すために利用する。
     */
    let undecidedInputs: Set<String>

    init(contentsOf url: URL) throws {
        var table: [String: Moji] = [:]
        var undecidedInputs: Set<String> = []
        var error: RomajiError? = nil
        var lineNumber = 0
        try String(contentsOf: url, encoding: .utf8).enumerateLines { line, stop in
            lineNumber += 1
            // #で始まる行はコメント行
            if line.starts(with: "#") || line.isEmpty {
                return
            }
            // TODO: 正規表現などで一要素目がキーボードから直接入力できるASCII文字であることを検査する
            let elements = line.split(separator: ",", maxSplits: 5).map {
                $0.replacingOccurrences(of: "&comma;", with: ",")
            }
            if elements.count < 2 || elements.contains(where: { $0.isEmpty }) {
                logger.error("ローマ字変換定義ファイルの \(lineNumber) 行目の記述が壊れています")
                error = RomajiError.invalid
                stop = true
                return
            }
            let firstRomaji = elements.count == 5 ? elements[4] : String(elements[0].first!)
            let katakana = elements.count > 2 ? elements[2] : nil
            let hankaku = elements.count > 3 ? elements[3] : nil
            let remain = elements.count > 4 ? elements[4] : nil
            table[elements[0]] = Moji(firstRomaji: firstRomaji,
                                      kana: elements[1],
                                      katakana: katakana,
                                      hankaku: hankaku,
                                      remain: remain)
            if elements[0].count > 1 {
                undecidedInputs.insert(String(elements[0].dropLast()))
            }
        }
        if let error {
            throw error
        }
        self.table = table
        self.undecidedInputs = undecidedInputs
    }

    /**
     * ローマ字文字列を受け取り、かな確定文字と残りのローマ字文字列を返す.
     *
     * - "ka" が入力されたら確定文字 "か" と残りのローマ字文字列 "" を返す
     * - "k" が入力されたら確定文字はnil, 残りのローマ字文字列 "k" を返す
     * - "kt" のように連続できない子音が連続したinputの場合は"k"を捨てて"t"をinput引数としたときのconvertの結果を返す
     * - "kya" のように確定した文字が複数の場合がありえる
     * - "aiueo" のように複数の確定が可能な場合は最初に確定できた文字だけを確定文字として返し、残りは(確定可能だが)inputとして返す
     * - ",", "." は"、", "。"にする (将来設定で切り変えられるようにするかも)
     * - "1" のように非ローマ字文字列を受け取った場合は未定義とする (呼び出し側で処理する予定だけどここで処理するかも)
     */
    func convert(_ input: String) -> ConvertedMoji {
        if let moji = table[input] {
            return ConvertedMoji(input: moji.remain ?? "", kakutei: moji)
        } else if undecidedInputs.contains(input) {
            return ConvertedMoji(input: input, kakutei: nil)
        } else if input.hasPrefix("n") && input.count == 2 {
            return ConvertedMoji(input: String(input.dropFirst()), kakutei: Romaji.n)
        } else if input.count > 1, let c = input.last {
            return convert(String(c))
        }
        return ConvertedMoji(input: input, kakutei: nil)
    }
}
