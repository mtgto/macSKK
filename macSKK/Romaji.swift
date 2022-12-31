// SPDX-FileCopyrightText: 2022 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

struct Romaji: Equatable {
    struct Moji: Equatable {
        /**
         * SKK辞書で表現されるローマ字
         *
         * - TODO: EmacsのSKK基準で実装する。とりあえず不明なものは空文字列にしている。
         */
        let firstRomaji: String
        let hiragana: String
        let katakana: String
        let hankaku: String

        func string(for mode: InputMode) -> String {
            switch mode {
            case .hiragana:
                return hiragana
            case .katakana:
                return katakana
            case .hankaku:
                return hankaku
            default:
                fatalError("Called Romaji.Moji.string from wrong mode \(mode)")
            }
        }
    }

    /**
     * 入力されたローマ字をMojiに変換した結果
     */
    struct ConvertedMoji: Equatable {
        let input: String
        let kakutei: Moji?
    }

    static let n = Moji(firstRomaji: "n", hiragana: "ん", katakana: "ン", hankaku: "ﾝ")
    static func sokuon(_ firstRomaji: String) -> Moji {
        Moji(firstRomaji: firstRomaji, hiragana: "っ", katakana: "ッ", hankaku: "ｯ")
    }

    // ローマ字から平仮名、カタカナ、半角カタカナへの辞書
    // ref. https://ja.wikipedia.org/wiki/%E3%83%AD%E3%83%BC%E3%83%9E%E5%AD%97%E5%85%A5%E5%8A%9B
    static let table: [String: Moji] = [
        "a": Moji(firstRomaji: "a", hiragana: "あ", katakana: "ア", hankaku: "ｱ"),
        "i": Moji(firstRomaji: "i", hiragana: "い", katakana: "イ", hankaku: "ｲ"),
        "u": Moji(firstRomaji: "u", hiragana: "う", katakana: "ウ", hankaku: "ｳ"),
        "e": Moji(firstRomaji: "e", hiragana: "え", katakana: "エ", hankaku: "ｴ"),
        "o": Moji(firstRomaji: "o", hiragana: "お", katakana: "オ", hankaku: "ｵ"),
        "ka": Moji(firstRomaji: "k", hiragana: "か", katakana: "カ", hankaku: "ｶ"),
        "ki": Moji(firstRomaji: "k", hiragana: "き", katakana: "キ", hankaku: "ｷ"),
        "ku": Moji(firstRomaji: "k", hiragana: "く", katakana: "ク", hankaku: "ｸ"),
        "ke": Moji(firstRomaji: "k", hiragana: "け", katakana: "ケ", hankaku: "ｹ"),
        "ko": Moji(firstRomaji: "k", hiragana: "こ", katakana: "コ", hankaku: "ｺ"),
        "sa": Moji(firstRomaji: "s", hiragana: "さ", katakana: "サ", hankaku: "ｻ"),
        "si": Moji(firstRomaji: "s", hiragana: "し", katakana: "シ", hankaku: "ｼ"),
        "shi": Moji(firstRomaji: "s", hiragana: "し", katakana: "シ", hankaku: "ｼ"),
        "su": Moji(firstRomaji: "s", hiragana: "す", katakana: "ス", hankaku: "ｽ"),
        "se": Moji(firstRomaji: "s", hiragana: "せ", katakana: "セ", hankaku: "ｾ"),
        "so": Moji(firstRomaji: "s", hiragana: "そ", katakana: "ソ", hankaku: "ｿ"),
        "ta": Moji(firstRomaji: "t", hiragana: "た", katakana: "タ", hankaku: "ﾀ"),
        "ti": Moji(firstRomaji: "t", hiragana: "ち", katakana: "チ", hankaku: "ﾁ"),
        "chi": Moji(firstRomaji: "t", hiragana: "ち", katakana: "チ", hankaku: "ﾁ"),
        "tu": Moji(firstRomaji: "t", hiragana: "つ", katakana: "ツ", hankaku: "ﾂ"),
        "tsu": Moji(firstRomaji: "t", hiragana: "つ", katakana: "ツ", hankaku: "ﾂ"),
        "te": Moji(firstRomaji: "t", hiragana: "て", katakana: "テ", hankaku: "ﾃ"),
        "to": Moji(firstRomaji: "t", hiragana: "と", katakana: "ト", hankaku: "ﾄ"),
        "na": Moji(firstRomaji: "n", hiragana: "な", katakana: "ナ", hankaku: "ﾅ"),
        "ni": Moji(firstRomaji: "n", hiragana: "に", katakana: "ニ", hankaku: "ﾆ"),
        "nu": Moji(firstRomaji: "n", hiragana: "ぬ", katakana: "ヌ", hankaku: "ﾇ"),
        "ne": Moji(firstRomaji: "n", hiragana: "ね", katakana: "ネ", hankaku: "ﾈ"),
        "no": Moji(firstRomaji: "n", hiragana: "の", katakana: "ノ", hankaku: "ﾉ"),
        "ha": Moji(firstRomaji: "h", hiragana: "は", katakana: "ハ", hankaku: "ﾊ"),
        "hi": Moji(firstRomaji: "h", hiragana: "ひ", katakana: "ヒ", hankaku: "ﾋ"),
        "hu": Moji(firstRomaji: "h", hiragana: "ふ", katakana: "フ", hankaku: "ﾌ"),
        "he": Moji(firstRomaji: "h", hiragana: "へ", katakana: "ヘ", hankaku: "ﾍ"),
        "ho": Moji(firstRomaji: "h", hiragana: "ほ", katakana: "ホ", hankaku: "ﾎ"),
        "ma": Moji(firstRomaji: "m", hiragana: "ま", katakana: "マ", hankaku: "ﾏ"),
        "mi": Moji(firstRomaji: "m", hiragana: "み", katakana: "ミ", hankaku: "ﾐ"),
        "mu": Moji(firstRomaji: "m", hiragana: "む", katakana: "ム", hankaku: "ﾑ"),
        "me": Moji(firstRomaji: "m", hiragana: "め", katakana: "メ", hankaku: "ﾒ"),
        "mo": Moji(firstRomaji: "m", hiragana: "も", katakana: "モ", hankaku: "ﾓ"),
        "ya": Moji(firstRomaji: "y", hiragana: "や", katakana: "ヤ", hankaku: "ﾔ"),
        "yu": Moji(firstRomaji: "y", hiragana: "ゆ", katakana: "ユ", hankaku: "ﾕ"),
        "yo": Moji(firstRomaji: "y", hiragana: "よ", katakana: "ヨ", hankaku: "ﾖ"),
        "ra": Moji(firstRomaji: "r", hiragana: "ら", katakana: "ラ", hankaku: "ﾗ"),
        "ri": Moji(firstRomaji: "r", hiragana: "り", katakana: "リ", hankaku: "ﾘ"),
        "ru": Moji(firstRomaji: "r", hiragana: "る", katakana: "ル", hankaku: "ﾙ"),
        "re": Moji(firstRomaji: "r", hiragana: "れ", katakana: "レ", hankaku: "ﾚ"),
        "ro": Moji(firstRomaji: "r", hiragana: "ろ", katakana: "ロ", hankaku: "ﾛ"),
        "wa": Moji(firstRomaji: "w", hiragana: "わ", katakana: "ワ", hankaku: "ﾜ"),
        "wo": Moji(firstRomaji: "w", hiragana: "を", katakana: "ヲ", hankaku: "ｦ"),
        "nn": Moji(firstRomaji: "n", hiragana: "ん", katakana: "ン", hankaku: "ﾝ"),
        "ga": Moji(firstRomaji: "g", hiragana: "が", katakana: "ガ", hankaku: "ｶﾞ"),
        "gi": Moji(firstRomaji: "g", hiragana: "ぎ", katakana: "ギ", hankaku: "ｷﾞ"),
        "gu": Moji(firstRomaji: "g", hiragana: "ぐ", katakana: "グ", hankaku: "ｸﾞ"),
        "ge": Moji(firstRomaji: "g", hiragana: "げ", katakana: "ゲ", hankaku: "ｹﾞ"),
        "go": Moji(firstRomaji: "g", hiragana: "ご", katakana: "ゴ", hankaku: "ｺﾞ"),
        "za": Moji(firstRomaji: "z", hiragana: "ざ", katakana: "ザ", hankaku: "ｻﾞ"),
        "zi": Moji(firstRomaji: "z", hiragana: "じ", katakana: "ジ", hankaku: "ｼﾞ"),
        "ji": Moji(firstRomaji: "z", hiragana: "じ", katakana: "ジ", hankaku: "ｼﾞ"),
        "zu": Moji(firstRomaji: "z", hiragana: "ず", katakana: "ズ", hankaku: "ｽﾞ"),
        "ze": Moji(firstRomaji: "z", hiragana: "ぜ", katakana: "ゼ", hankaku: "ｾﾞ"),
        "zo": Moji(firstRomaji: "z", hiragana: "ぞ", katakana: "ゾ", hankaku: "ｿﾞ"),
        "da": Moji(firstRomaji: "d", hiragana: "だ", katakana: "ダ", hankaku: "ﾀﾞ"),
        "di": Moji(firstRomaji: "d", hiragana: "ぢ", katakana: "ヂ", hankaku: "ﾁﾞ"),
        "du": Moji(firstRomaji: "d", hiragana: "づ", katakana: "ヅ", hankaku: "ﾂﾞ"),
        "de": Moji(firstRomaji: "d", hiragana: "で", katakana: "デ", hankaku: "ﾃﾞ"),
        "do": Moji(firstRomaji: "d", hiragana: "ど", katakana: "ド", hankaku: "ﾄﾞ"),
        "ba": Moji(firstRomaji: "b", hiragana: "ば", katakana: "バ", hankaku: "ﾊﾞ"),
        "bi": Moji(firstRomaji: "b", hiragana: "び", katakana: "ビ", hankaku: "ﾋﾞ"),
        "bu": Moji(firstRomaji: "b", hiragana: "ぶ", katakana: "ブ", hankaku: "ﾌﾞ"),
        "be": Moji(firstRomaji: "b", hiragana: "べ", katakana: "ベ", hankaku: "ﾍﾞ"),
        "bo": Moji(firstRomaji: "b", hiragana: "ぼ", katakana: "ボ", hankaku: "ﾎﾞ"),
        "pa": Moji(firstRomaji: "p", hiragana: "ぱ", katakana: "パ", hankaku: "ﾊﾟ"),
        "pi": Moji(firstRomaji: "p", hiragana: "ぴ", katakana: "ピ", hankaku: "ﾋﾟ"),
        "pu": Moji(firstRomaji: "p", hiragana: "ぷ", katakana: "プ", hankaku: "ﾌﾟ"),
        "pe": Moji(firstRomaji: "p", hiragana: "ぺ", katakana: "ペ", hankaku: "ﾍﾟ"),
        "po": Moji(firstRomaji: "p", hiragana: "ぽ", katakana: "ポ", hankaku: "ﾎﾟ"),
        "kya": Moji(firstRomaji: "k", hiragana: "きゃ", katakana: "キャ", hankaku: "ｷｬ"),
        "kyu": Moji(firstRomaji: "k", hiragana: "きゅ", katakana: "キュ", hankaku: "ｷｭ"),
        "kyo": Moji(firstRomaji: "k", hiragana: "きょ", katakana: "キョ", hankaku: "ｷｮ"),
        "sya": Moji(firstRomaji: "s", hiragana: "しゃ", katakana: "シャ", hankaku: "ｼｬ"),
        "sha": Moji(firstRomaji: "s", hiragana: "しゃ", katakana: "シャ", hankaku: "ｼｬ"),
        "syu": Moji(firstRomaji: "s", hiragana: "しゅ", katakana: "シュ", hankaku: "ｼｭ"),
        "shu": Moji(firstRomaji: "s", hiragana: "しゅ", katakana: "シュ", hankaku: "ｼｭ"),
        "syo": Moji(firstRomaji: "s", hiragana: "しょ", katakana: "ショ", hankaku: "ｼｮ"),
        "sho": Moji(firstRomaji: "s", hiragana: "しょ", katakana: "ショ", hankaku: "ｼｮ"),
        "tya": Moji(firstRomaji: "t", hiragana: "ちゃ", katakana: "チャ", hankaku: "ﾁｬ"),
        "cha": Moji(firstRomaji: "t", hiragana: "ちゃ", katakana: "チャ", hankaku: "ﾁｬ"),
        "tyu": Moji(firstRomaji: "t", hiragana: "ちゅ", katakana: "チュ", hankaku: "ﾁｭ"),
        "chu": Moji(firstRomaji: "t", hiragana: "ちゅ", katakana: "チュ", hankaku: "ﾁｭ"),
        "tyo": Moji(firstRomaji: "t", hiragana: "ちょ", katakana: "チョ", hankaku: "ﾁｮ"),
        "cho": Moji(firstRomaji: "t", hiragana: "ちょ", katakana: "チョ", hankaku: "ﾁｮ"),
        "nya": Moji(firstRomaji: "n", hiragana: "にゃ", katakana: "ニャ", hankaku: "ﾆｬ"),
        "nyu": Moji(firstRomaji: "n", hiragana: "にゅ", katakana: "ニュ", hankaku: "ﾆｭ"),
        "nyo": Moji(firstRomaji: "n", hiragana: "にょ", katakana: "ニョ", hankaku: "ﾆｮ"),
        "hya": Moji(firstRomaji: "h", hiragana: "ひゃ", katakana: "ヒャ", hankaku: "ﾋｬ"),
        "hyu": Moji(firstRomaji: "h", hiragana: "ひゅ", katakana: "ヒュ", hankaku: "ﾋｭ"),
        "hyo": Moji(firstRomaji: "h", hiragana: "ひょ", katakana: "ヒョ", hankaku: "ﾋｮ"),
        "mya": Moji(firstRomaji: "m", hiragana: "みゃ", katakana: "ミャ", hankaku: "ﾐｬ"),
        "myu": Moji(firstRomaji: "m", hiragana: "みゅ", katakana: "ミュ", hankaku: "ﾐｭ"),
        "myo": Moji(firstRomaji: "m", hiragana: "みょ", katakana: "ミョ", hankaku: "ﾐｮ"),
        "rya": Moji(firstRomaji: "r", hiragana: "りゃ", katakana: "リャ", hankaku: "ﾘｬ"),
        "ryu": Moji(firstRomaji: "r", hiragana: "りゅ", katakana: "リュ", hankaku: "ﾘｭ"),
        "ryo": Moji(firstRomaji: "r", hiragana: "りょ", katakana: "リョ", hankaku: "ﾘｮ"),
        "gya": Moji(firstRomaji: "g", hiragana: "ぎゃ", katakana: "ギャ", hankaku: "ｷﾞｬ"),
        "gyu": Moji(firstRomaji: "g", hiragana: "ぎゅ", katakana: "ギュ", hankaku: "ｷﾞｭ"),
        "gyo": Moji(firstRomaji: "g", hiragana: "ぎょ", katakana: "ギョ", hankaku: "ｷﾞｮ"),
        "zya": Moji(firstRomaji: "z", hiragana: "じゃ", katakana: "ジャ", hankaku: "ｼﾞｬ"),
        "ja": Moji(firstRomaji: "z", hiragana: "じゃ", katakana: "ジャ", hankaku: "ｼﾞｬ"),
        "zyu": Moji(firstRomaji: "z", hiragana: "じゅ", katakana: "ジュ", hankaku: "ｼﾞｭ"),
        "ju": Moji(firstRomaji: "z", hiragana: "じゅ", katakana: "ジュ", hankaku: "ｼﾞｭ"),
        "zyo": Moji(firstRomaji: "z", hiragana: "じょ", katakana: "ジョ", hankaku: "ｼﾞｮ"),
        "jo": Moji(firstRomaji: "z", hiragana: "じょ", katakana: "ジョ", hankaku: "ｼﾞｮ"),
        "dya": Moji(firstRomaji: "d", hiragana: "ぢゃ", katakana: "ヂャ", hankaku: "ﾁﾞｬ"),
        "dyu": Moji(firstRomaji: "d", hiragana: "ぢゅ", katakana: "ヂュ", hankaku: "ﾁﾞｭ"),
        "dyo": Moji(firstRomaji: "d", hiragana: "ぢょ", katakana: "ヂョ", hankaku: "ﾁﾞｮ"),
        "bya": Moji(firstRomaji: "b", hiragana: "びゃ", katakana: "ビャ", hankaku: "ﾋﾞｬ"),
        "byu": Moji(firstRomaji: "b", hiragana: "びゅ", katakana: "ビュ", hankaku: "ﾋﾞｭ"),
        "byo": Moji(firstRomaji: "b", hiragana: "びょ", katakana: "ビョ", hankaku: "ﾋﾞｮ"),
        "pya": Moji(firstRomaji: "p", hiragana: "ぴゃ", katakana: "ピャ", hankaku: "ﾋﾟｬ"),
        "pyu": Moji(firstRomaji: "p", hiragana: "ぴゅ", katakana: "ピュ", hankaku: "ﾋﾟｭ"),
        "pyo": Moji(firstRomaji: "p", hiragana: "ぴょ", katakana: "ピョ", hankaku: "ﾋﾟｮ"),
        "sye": Moji(firstRomaji: "s", hiragana: "しぇ", katakana: "シェ", hankaku: "ｼｪ"),
        "she": Moji(firstRomaji: "s", hiragana: "しぇ", katakana: "シェ", hankaku: "ｼｪ"),
        "tye": Moji(firstRomaji: "t", hiragana: "ちぇ", katakana: "チェ", hankaku: "ﾁｪ"),
        "che": Moji(firstRomaji: "t", hiragana: "ちぇ", katakana: "チェ", hankaku: "ﾁｪ"),
        "tsa": Moji(firstRomaji: "t", hiragana: "つぁ", katakana: "ツァ", hankaku: "ﾂｧ"),
        "tse": Moji(firstRomaji: "t", hiragana: "つぇ", katakana: "ツェ", hankaku: "ﾂｪ"),
        "tso": Moji(firstRomaji: "t", hiragana: "つぉ", katakana: "ツォ", hankaku: "ﾂｫ"),
        "thi": Moji(firstRomaji: "t", hiragana: "てぃ", katakana: "ティ", hankaku: "ﾃｨ"),
        "fa": Moji(firstRomaji: "f", hiragana: "ふぁ", katakana: "ファ", hankaku: "ﾌｧ"),
        "fi": Moji(firstRomaji: "f", hiragana: "ふぃ", katakana: "フィ", hankaku: "ﾌｨ"),
        "fe": Moji(firstRomaji: "f", hiragana: "ふぇ", katakana: "フェ", hankaku: "ﾌｪ"),
        "fo": Moji(firstRomaji: "f", hiragana: "ふぉ", katakana: "フォ", hankaku: "ﾌｫ"),
        "zye": Moji(firstRomaji: "z", hiragana: "じぇ", katakana: "ジェ", hankaku: "ｼﾞｪ"),
        "je": Moji(firstRomaji: "z", hiragana: "じぇ", katakana: "ジェ", hankaku: "ｼﾞｪ"),
        "dye": Moji(firstRomaji: "d", hiragana: "ぢぇ", katakana: "ヂェ", hankaku: "ﾁﾞｪ"),
        "dhi": Moji(firstRomaji: "d", hiragana: "でぃ", katakana: "ディ", hankaku: "ﾃﾞｨ"),
        "dhu": Moji(firstRomaji: "d", hiragana: "でゅ", katakana: "デュ", hankaku: "ﾃﾞｭ"),
        "xa": Moji(firstRomaji: "", hiragana: "ぁ", katakana: "ァ", hankaku: "ｧ"),
        "xi": Moji(firstRomaji: "", hiragana: "ぃ", katakana: "ィ", hankaku: "ｨ"),
        "xu": Moji(firstRomaji: "", hiragana: "ぅ", katakana: "ゥ", hankaku: "ｩ"),
        "xe": Moji(firstRomaji: "", hiragana: "ぇ", katakana: "ェ", hankaku: "ｪ"),
        "xo": Moji(firstRomaji: "", hiragana: "ぉ", katakana: "ォ", hankaku: "ｫ"),
        "xka": Moji(firstRomaji: "", hiragana: "ヵ", katakana: "ヵ", hankaku: "ｶ"),
        "xke": Moji(firstRomaji: "", hiragana: "ヶ", katakana: "ヶ", hankaku: "ｹ"),
        "xtu": Moji(firstRomaji: "", hiragana: "っ", katakana: "ッ", hankaku: "ｯ"),
        "xya": Moji(firstRomaji: "", hiragana: "ゃ", katakana: "ャ", hankaku: "ｬ"),
        "xyu": Moji(firstRomaji: "", hiragana: "ゅ", katakana: "ュ", hankaku: "ｭ"),
        "xyo": Moji(firstRomaji: "", hiragana: "ょ", katakana: "ョ", hankaku: "ｮ"),
        "xwa": Moji(firstRomaji: "", hiragana: "ゎ", katakana: "ヮ", hankaku: "ﾜ"),
        // 追加で実装したほうがよい入力方法
        "ye": Moji(firstRomaji: "", hiragana: "いぇ", katakana: "イェ", hankaku: "ｲｪ"),
        "whi": Moji(firstRomaji: "", hiragana: "うぃ", katakana: "ウィ", hankaku: "ｳｨ"),
        "wi": Moji(firstRomaji: "", hiragana: "うぃ", katakana: "ウィ", hankaku: "ｳｨ"),
        "whe": Moji(firstRomaji: "", hiragana: "うぇ", katakana: "ウェ", hankaku: "ｳｪ"),
        "we": Moji(firstRomaji: "", hiragana: "うぇ", katakana: "ウェ", hankaku: "ｳｪ"),
        "va": Moji(firstRomaji: "", hiragana: "う゛ぁ", katakana: "ヴァ", hankaku: "ｳﾞｧ"),
        "vi": Moji(firstRomaji: "", hiragana: "う゛ぃ", katakana: "ヴィ", hankaku: "ｳﾞｨ"),
        "vu": Moji(firstRomaji: "", hiragana: "う゛ぅ", katakana: "ヴ", hankaku: "ｳﾞ"),
        "ve": Moji(firstRomaji: "", hiragana: "う゛ぇ", katakana: "ヴェ", hankaku: "ｳﾞｪ"),
        "vo": Moji(firstRomaji: "", hiragana: "う゛ぉ", katakana: "ヴォ", hankaku: "ｳﾞｫ"),
        "vyu": Moji(firstRomaji: "", hiragana: "う゛ゅ", katakana: "ヴュ", hankaku: "ｳﾞｭ"),
        "kwa": Moji(firstRomaji: "", hiragana: "くぁ", katakana: "クァ", hankaku: "ｸｧ"),
        "qa": Moji(firstRomaji: "", hiragana: "くぁ", katakana: "クァ", hankaku: "ｸｧ"),
        "kwi": Moji(firstRomaji: "", hiragana: "くぃ", katakana: "クィ", hankaku: "ｸｨ"),
        "qi": Moji(firstRomaji: "", hiragana: "くぃ", katakana: "クィ", hankaku: "ｸｨ"),
        "kwe": Moji(firstRomaji: "", hiragana: "くぇ", katakana: "クェ", hankaku: "ｸｪ"),
        "qe": Moji(firstRomaji: "", hiragana: "くぇ", katakana: "クェ", hankaku: "ｸｪ"),
        "kwo": Moji(firstRomaji: "", hiragana: "くぉ", katakana: "クォ", hankaku: "ｸｫ"),
        "qo": Moji(firstRomaji: "", hiragana: "くぉ", katakana: "クォ", hankaku: "ｸｫ"),
        "gwa": Moji(firstRomaji: "", hiragana: "ぐぁ", katakana: "グァ", hankaku: "ｸﾞｧ"),
        "jya": Moji(firstRomaji: "", hiragana: "じゃ", katakana: "ジャ", hankaku: "ｼﾞｬ"),
        "jyu": Moji(firstRomaji: "", hiragana: "じゅ", katakana: "ジュ", hankaku: "ｼﾞｭ"),
        "jyo": Moji(firstRomaji: "", hiragana: "じょ", katakana: "ジョ", hankaku: "ｼﾞｮ"),
        "cya": Moji(firstRomaji: "", hiragana: "ちゃ", katakana: "チャ", hankaku: "ﾁｬ"),
        "cyu": Moji(firstRomaji: "", hiragana: "ちゅ", katakana: "チュ", hankaku: "ﾁｭ"),
        "cyo": Moji(firstRomaji: "", hiragana: "ちょ", katakana: "チョ", hankaku: "ﾁｮ"),
        "tsi": Moji(firstRomaji: "", hiragana: "つぃ", katakana: "ツィ", hankaku: "ﾂｨ"),
        "thu": Moji(firstRomaji: "", hiragana: "てゅ", katakana: "テュ", hankaku: "ﾃｭ"),
        "twu": Moji(firstRomaji: "", hiragana: "とぅ", katakana: "トゥ", hankaku: "ﾄｩ"),
        "dwu": Moji(firstRomaji: "", hiragana: "どぅ", katakana: "ドゥ", hankaku: "ﾄﾞｩ"),
        "hwa": Moji(firstRomaji: "", hiragana: "ふぁ", katakana: "ファ", hankaku: "ﾌｧ"),
        "hwi": Moji(firstRomaji: "", hiragana: "ふぃ", katakana: "フィ", hankaku: "ﾌｨ"),
        "hwe": Moji(firstRomaji: "", hiragana: "ふぇ", katakana: "フェ", hankaku: "ﾌｪ"),
        "hwo": Moji(firstRomaji: "", hiragana: "ふぉ", katakana: "フォ", hankaku: "ﾌｫ"),
        "fwu": Moji(firstRomaji: "", hiragana: "ふゅ", katakana: "フュ", hankaku: "ﾌｭ"),
        "xtsu": Moji(firstRomaji: "t", hiragana: "っ", katakana: "ッ", hankaku: "ｯ"),
    ]

    static let symbolTable: [String: Moji] = [
        "-": Moji(firstRomaji: "-", hiragana: "ー", katakana: "ー", hankaku: "-"),
        ",": Moji(firstRomaji: "", hiragana: "、", katakana: "、", hankaku: "､"),
        ".": Moji(firstRomaji: "", hiragana: "。", katakana: "。", hankaku: "｡"),
    ]

    // 設定で有効化するかも? 普段使いにないと不便すぎるので追加
    static let specialSymbolTable: [String: Moji] = [
        "z-": Moji(firstRomaji: "", hiragana: "～", katakana: "～", hankaku: "～"),
        "z,": Moji(firstRomaji: "", hiragana: "‥", katakana: "‥", hankaku: "‥"),
        "z.": Moji(firstRomaji: "", hiragana: "…", katakana: "…", hankaku: "…"),
        "z/": Moji(firstRomaji: "", hiragana: "・", katakana: "・", hankaku: "･"),
        "zh": Moji(firstRomaji: "", hiragana: "←", katakana: "←", hankaku: "←"),
        "zj": Moji(firstRomaji: "", hiragana: "↓", katakana: "↓", hankaku: "↓"),
        "zk": Moji(firstRomaji: "", hiragana: "↑", katakana: "↑", hankaku: "↑"),
        "zl": Moji(firstRomaji: "", hiragana: "→", katakana: "→", hankaku: "→"),
        "z ": Moji(firstRomaji: "", hiragana: "　", katakana: "　", hankaku: "　"),
    ]

    /**
     * ローマ字文字列を受け取り、かな確定文字と残りのローマ字文字列を返す.
     *
     * - "ka" が入力されたら確定文字 "か" と残りのローマ字文字列 "" を返す
     * - "k" が入力されたら確定文字はnil, 残りのローマ字文字列 "k" を返す
     * - "kt" のように連続できない子音が連続したinputの場合は"t"だけをローマ字文字列として返す
     * - "aiueo" のように複数の確定が可能な場合は最初に確定できた文字だけを確定文字として返し、残りは(確定可能だが)inputとして返す
     * - ",", "." は"、", "。"にする (将来設定で切り変えられるようにするかも)
     * - "1" のように非ローマ字文字列を受け取った場合は未定義とする (呼び出し側で処理する予定だけどここで処理するかも)
     */
    static func convert(_ input: String) -> ConvertedMoji {
        let array = [
            "sh", "ts", "ky", "sy", "ty", "ch", "ny", "hy", "my", "ry", "gy", "zy", "dy", "by", "py", "th", "xk", "xt",
            "xy", "xw", "wh", "vy", "kw", "gw", "jy", "cy", "dw", "hw", "fw", "xts",
        ]
        if let moji = table[input] {
            return ConvertedMoji(input: "", kakutei: moji)
        } else if ["kk", "ss", "tt", "cc", "hh", "mm", "yy", "rr", "ww", "gg", "zz", "jj", "dd", "bb", "pp"].contains(
            where: { input.hasPrefix($0) })
        {
            return ConvertedMoji(input: String(input.dropFirst()), kakutei: Romaji.sokuon(String(input.first!)))
        } else if input == "nn" {
            return ConvertedMoji(input: "", kakutei: Romaji.n)
        } else if let symbol = symbolTable[input] {
            return ConvertedMoji(input: "", kakutei: symbol)
        } else if let symbol = specialSymbolTable[input] {
            return ConvertedMoji(input: "", kakutei: symbol)
        } else if ["nk", "ns", "nt", "nc", "nt", "nh", "nm", "nr", "nw", "ng", "nz", "nj", "nd", "nb", "np"].contains(
            where: { input.hasPrefix($0) })
        {
            return ConvertedMoji(input: String(input.dropFirst()), kakutei: Romaji.n)
        } else if array.contains(input) {
            return ConvertedMoji(input: input, kakutei: nil)
        } else if let firstIndex = array.firstIndex(where: { input.hasPrefix($0) }) {
            return ConvertedMoji(input: String(input.dropFirst(array[firstIndex].utf8.count)), kakutei: nil)
        } else if let c = input.last {
            return ConvertedMoji(input: String(c), kakutei: nil)
        }
        return ConvertedMoji(input: input, kakutei: nil)
    }
}
