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
    }

    func testConvert() throws {
        let fileURL = Bundle(for: Self.self).url(forResource: "kana-rule-for-test", withExtension: "conf")!
        let kanaRule = try Romaji(contentsOf: fileURL)
        XCTAssertEqual(kanaRule.convert("a"), Romaji.ConvertedMoji(input: "", kakutei: Romaji.Moji(firstRomaji: "a", kana: "あ"), dropped: nil))
        // nだけではまだ「ん」になるかは確定しない (な行などに派生する可能性がある)
        XCTAssertEqual(kanaRule.convert("n"), Romaji.ConvertedMoji(input: "n", kakutei: nil, dropped: nil))
        XCTAssertEqual(kanaRule.convert("na"), Romaji.ConvertedMoji(input: "", kakutei: Romaji.Moji(firstRomaji: "n", kana: "な"), dropped: nil))
        XCTAssertEqual(kanaRule.convert("ga"), Romaji.ConvertedMoji(input: "", kakutei: Romaji.Moji(firstRomaji: "g", kana: "が"), dropped: nil))
        XCTAssertEqual(kanaRule.convert("ji"), Romaji.ConvertedMoji(input: "", kakutei: Romaji.Moji(firstRomaji: "j", kana: "じ"), dropped: nil))
        XCTAssertEqual(kanaRule.convert("zi"), Romaji.ConvertedMoji(input: "", kakutei: Romaji.Moji(firstRomaji: "j", kana: "じ"), dropped: nil), "かなが「じ」のときはfirstRomajiはj固定")
        XCTAssertEqual(kanaRule.convert("nn"), Romaji.ConvertedMoji(input: "", kakutei: Romaji.Moji(firstRomaji: "n", kana: "ん"), dropped: nil))
        XCTAssertEqual(kanaRule.convert("nk"), Romaji.ConvertedMoji(input: "k", kakutei: Romaji.Moji(firstRomaji: "n", kana: "ん"), dropped: nil))
        XCTAssertEqual(kanaRule.convert("n!"), Romaji.ConvertedMoji(input: "!", kakutei: Romaji.Moji(firstRomaji: "n", kana: "ん"), dropped: nil))
        XCTAssertEqual(kanaRule.convert("kn"), Romaji.ConvertedMoji(input: "n", kakutei: nil, dropped: "k"))
        XCTAssertEqual(kanaRule.convert("ny"), Romaji.ConvertedMoji(input: "ny", kakutei: nil, dropped: nil))
        XCTAssertEqual(kanaRule.convert("nya"), Romaji.ConvertedMoji(input: "", kakutei: Romaji.Moji(firstRomaji: "n", kana: "にゃ"), dropped: nil))
        XCTAssertEqual(kanaRule.convert("kk"), Romaji.ConvertedMoji(input: "k", kakutei: Romaji.Moji(firstRomaji: "k", kana: "っ", katakana: "ッ", hankaku: "ｯ", remain: "k"), dropped: nil))
        XCTAssertEqual(kanaRule.convert("nyk"), Romaji.ConvertedMoji(input: "k", kakutei: nil, dropped: "ny"), "続けられない子音が連続した場合は最後の子音だけ残る")
        XCTAssertEqual(kanaRule.convert("z,"), Romaji.ConvertedMoji(input: "", kakutei: Romaji.Moji(firstRomaji: "z", kana: "‥"), dropped: nil))
        XCTAssertEqual(kanaRule.convert("x,,"), Romaji.ConvertedMoji(input: "", kakutei: Romaji.Moji(firstRomaji: "d", kana: "だぶるかんま"), dropped: nil), "firstRomajiはかなの一文字目から決定される")
        XCTAssertEqual(kanaRule.convert("@"), Romaji.ConvertedMoji(input: "@", kakutei: nil, dropped: nil), "ルールにない文字は変換されない")
        XCTAssertEqual(kanaRule.convert("a;"), Romaji.ConvertedMoji(input: "", kakutei: Romaji.Moji(firstRomaji: "a", kana:"あせみころん"), dropped: nil), "システム用の文字を含むことができる")
        XCTAssertEqual(kanaRule.convert("ca"), Romaji.ConvertedMoji(input: "", kakutei: Romaji.Moji(firstRomaji: "k", kana:"か"), dropped: nil), "実際に入力した一文字目(c)ではなく「か」からローマ字(k)に変換する")
    }

    func testVu() throws {
        var kanaRule = try Romaji(source: "vu,う゛")
        XCTAssertEqual(kanaRule.convert("vu").kakutei?.kana, "う゛")
        kanaRule = try Romaji(source: "vu,ゔ")
        XCTAssertEqual(kanaRule.convert("vu").kakutei?.kana, "ゔ")
    }
}
