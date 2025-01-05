// SPDX-FileCopyrightText: 2022 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

@testable import macSKK

class RomajiTests: XCTestCase {
    func testInit() {
        XCTAssertNoThrow(try Romaji(source: "# hoge"), "#で始まる行はコメント")
        XCTAssertThrowsError(try Romaji(source: ",あ"), "1要素目が空")
        XCTAssertThrowsError(try Romaji(source: "a,"), "2要素目が空")
        XCTAssertNoThrow(try Romaji(source: "&comma;,あ"), "カンマを使いたい場合は &comma; と書く")
        XCTAssertNoThrow(try Romaji(source: "+,<shift>っ"), "シフトキーを押しているときの記号のルール")
        XCTAssertThrowsError(try Romaji(source: "+,<shift>+"), "シフトキーを押しているときの記号のルールで左辺と右辺が一致")
    }

    func testConvert() throws {
        let fileURL = Bundle(for: Self.self).url(forResource: "kana-rule-for-test", withExtension: "conf")!
        let kanaRule = try Romaji(contentsOf: fileURL)
        XCTAssertEqual(kanaRule.convert("a", punctuation: .default), Romaji.ConvertedMoji(input: "", kakutei: Romaji.Moji(firstRomaji: "a", kana: "あ")))
        // nだけではまだ「ん」になるかは確定しない (な行などに派生する可能性がある)
        XCTAssertEqual(kanaRule.convert("n", punctuation: .default), Romaji.ConvertedMoji(input: "n", kakutei: nil))
        XCTAssertEqual(kanaRule.convert("na", punctuation: .default), Romaji.ConvertedMoji(input: "", kakutei: Romaji.Moji(firstRomaji: "n", kana: "な")))
        XCTAssertEqual(kanaRule.convert("ga", punctuation: .default), Romaji.ConvertedMoji(input: "", kakutei: Romaji.Moji(firstRomaji: "g", kana: "が")))
        XCTAssertEqual(kanaRule.convert("ji", punctuation: .default), Romaji.ConvertedMoji(input: "", kakutei: Romaji.Moji(firstRomaji: "j", kana: "じ")))
        XCTAssertEqual(kanaRule.convert("zi", punctuation: .default), Romaji.ConvertedMoji(input: "", kakutei: Romaji.Moji(firstRomaji: "j", kana: "じ")), "かなが「じ」のときはfirstRomajiはj固定")
        XCTAssertEqual(kanaRule.convert("nn", punctuation: .default), Romaji.ConvertedMoji(input: "", kakutei: Romaji.Moji(firstRomaji: "n", kana: "ん")))
        XCTAssertEqual(kanaRule.convert("nk", punctuation: .default), Romaji.ConvertedMoji(input: "k", kakutei: Romaji.Moji(firstRomaji: "n", kana: "ん")))
        XCTAssertEqual(kanaRule.convert("n!", punctuation: .default), Romaji.ConvertedMoji(input: "!", kakutei: Romaji.Moji(firstRomaji: "n", kana: "ん")))
        XCTAssertEqual(kanaRule.convert("kn", punctuation: .default), Romaji.ConvertedMoji(input: "n", kakutei: nil))
        XCTAssertEqual(kanaRule.convert("ny", punctuation: .default), Romaji.ConvertedMoji(input: "ny", kakutei: nil))
        XCTAssertEqual(kanaRule.convert("nya", punctuation: .default), Romaji.ConvertedMoji(input: "", kakutei: Romaji.Moji(firstRomaji: "n", kana: "にゃ")))
        XCTAssertEqual(kanaRule.convert("kk", punctuation: .default), Romaji.ConvertedMoji(input: "k", kakutei: Romaji.Moji(firstRomaji: "k", kana: "っ", katakana: "ッ", hankaku: "ｯ", remain: "k")))
        XCTAssertEqual(kanaRule.convert("nyk", punctuation: .default), Romaji.ConvertedMoji(input: "k", kakutei: nil), "続けられない子音が連続した場合は最後の子音だけ残る")
        XCTAssertEqual(kanaRule.convert("z,", punctuation: .default), Romaji.ConvertedMoji(input: "", kakutei: Romaji.Moji(firstRomaji: "z", kana: "‥")))
        XCTAssertEqual(kanaRule.convert("x,,", punctuation: .default), Romaji.ConvertedMoji(input: "", kakutei: Romaji.Moji(firstRomaji: "d", kana: "だぶるかんま")), "firstRomajiはかなの一文字目から決定される")
        XCTAssertEqual(kanaRule.convert("@", punctuation: .default), Romaji.ConvertedMoji(input: "@", kakutei: nil), "ルールにない文字は変換されない")
        XCTAssertEqual(kanaRule.convert("a;", punctuation: .default), Romaji.ConvertedMoji(input: "", kakutei: Romaji.Moji(firstRomaji: "a", kana:"あせみころん")), "システム用の文字を含むことができる")
        XCTAssertEqual(kanaRule.convert("ca", punctuation: .default), Romaji.ConvertedMoji(input: "", kakutei: Romaji.Moji(firstRomaji: "k", kana:"か")), "実際に入力した一文字目(c)ではなく「か」からローマ字(k)に変換する")
        // 読点
        XCTAssertEqual(kanaRule.convert(",", punctuation: Punctuation(comma: .ten, period: .default)), Romaji.ConvertedMoji(input: "", kakutei: Romaji.Moji(firstRomaji: ",", kana: "、")))
        XCTAssertEqual(kanaRule.convert(",", punctuation: Punctuation(comma: .comma, period: .default)), Romaji.ConvertedMoji(input: "", kakutei: Romaji.Moji(firstRomaji: ",", kana: "，")))
        // 句点
        XCTAssertEqual(kanaRule.convert(".", punctuation: Punctuation(comma: .default, period: .maru)), Romaji.ConvertedMoji(input: "", kakutei: Romaji.Moji(firstRomaji: ".", kana: "。")))
        XCTAssertEqual(kanaRule.convert(".", punctuation: Punctuation(comma: .default, period: .period)), Romaji.ConvertedMoji(input: "", kakutei: Romaji.Moji(firstRomaji: ".", kana: "．")))
        XCTAssertEqual(kanaRule.lowercaseMap["+"], ";")
        XCTAssertEqual(kanaRule.lowercaseMap[":"], ";")
    }

    func testConvertSpecialCharacters() throws {
        // AZIKのセミコロンを促音(っ)として扱う設定
        let kanaRule = try Romaji(source: ";,っ")
        // 入力はセミコロンでもfirstRomajiは "t" になる
        XCTAssertEqual(kanaRule.convert(";", punctuation: .default), Romaji.ConvertedMoji(input: "", kakutei: Romaji.Moji(firstRomaji: "t", kana: "っ")))
    }

    func testVu() throws {
        var kanaRule = try Romaji(source: "vu,う゛")
        XCTAssertEqual(kanaRule.convert("vu", punctuation: .default).kakutei?.kana, "う゛")
        kanaRule = try Romaji(source: "vu,ゔ")
        XCTAssertEqual(kanaRule.convert("vu", punctuation: .default).kakutei?.kana, "ゔ")
    }

    func testIsPrefix() throws {
        let kanaRule = Romaji.defaultKanaRule
        XCTAssertTrue(kanaRule.isPrefix(input: "a", modifierFlags: []))
        XCTAssertTrue(kanaRule.isPrefix(input: "a", modifierFlags: [.shift]))
        XCTAssertFalse(kanaRule.isPrefix(input: "a", modifierFlags: [.option]))
        XCTAssertFalse(kanaRule.isPrefix(input: "a", modifierFlags: [.shift, .option]))
        XCTAssertFalse(kanaRule.isPrefix(input: "a", modifierFlags: [.command]))
        XCTAssertFalse(kanaRule.isPrefix(input: "a", modifierFlags: [.control]))
        XCTAssertTrue(kanaRule.isPrefix(input: "k", modifierFlags: []))
        XCTAssertTrue(kanaRule.isPrefix(input: "ky", modifierFlags: []))
        XCTAssertTrue(kanaRule.isPrefix(input: "kya", modifierFlags: []))
        XCTAssertFalse(kanaRule.isPrefix(input: "kyi", modifierFlags: []))
        XCTAssertFalse(kanaRule.isPrefix(input: "q", modifierFlags: []))
        XCTAssertTrue(kanaRule.isPrefix(input: ",", modifierFlags: []))
        XCTAssertFalse(kanaRule.isPrefix(input: ",", modifierFlags: [.shift]))
    }
}

extension Romaji {
    // アプリデフォルトのローマ字かな変換ルール
    static var defaultKanaRule: Romaji {
        let kanaRuleFileURL = Bundle.main.url(forResource: "kana-rule", withExtension: "conf")!
        return try! Romaji(contentsOf: kanaRuleFileURL)
    }
}
