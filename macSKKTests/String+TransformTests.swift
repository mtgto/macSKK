// SPDX-FileCopyrightText: 2022 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

@testable import macSKK

final class StringTransformTests: XCTestCase {
    func testToZenkaku() throws {
        XCTAssertEqual("".toZenkaku(), "")
        XCTAssertEqual("a".toZenkaku(), "ａ")
        XCTAssertEqual("A".toZenkaku(), "Ａ")
        XCTAssertEqual(";".toZenkaku(), "；")
        XCTAssertEqual(" ".toZenkaku(), "　")
        XCTAssertEqual("ｱｯ".toZenkaku(), "アッ")
        XCTAssertEqual("ｸﾞｳﾞｪ".toZenkaku(), "グヴェ")
        XCTAssertEqual("､｡ｰ;".toZenkaku(), "、。ー；")
    }

    func testToHankaku() throws {
        XCTAssertEqual("".toHankaku(), "")
        XCTAssertEqual("ａ".toHankaku(), "a")
        XCTAssertEqual("Ａ".toHankaku(), "A")
        XCTAssertEqual("；".toHankaku(), ";")
        XCTAssertEqual("　".toHankaku(), " ")
        XCTAssertEqual("アッ".toHankaku(), "ｱｯ")
        XCTAssertEqual("グヴェ".toHankaku(), "ｸﾞｳﾞｪ")
        XCTAssertEqual("あいう123!@#".toHankaku(), "あいう123!@#")
        XCTAssertEqual("、。ー；".toHankaku(), "､｡ｰ;")

    }

    func testToKatakana() throws {
        XCTAssertEqual("".toKatakana(), "")
        XCTAssertEqual("あっ".toKatakana(), "アッ")
        XCTAssertEqual("ぐう゛ぇ".toKatakana(), "グヴェ")
        XCTAssertEqual("ぐゔぇ".toKatakana(), "グヴェ")
    }

    func testIsAlphabet() {
        XCTAssertTrue("".isAlphabet, "空文字列はtrue")
        XCTAssertTrue("abcdefghijklmnopqrstuvwxyz".isAlphabet)
        XCTAssertTrue("ABCDEFGHIJKLMNOPQRSTUVWXYZ".isAlphabet)
        XCTAssertFalse("1".isAlphabet)
        XCTAssertFalse("å".isAlphabet, "Option+A")
        XCTAssertFalse("!".isAlphabet)
        XCTAssertFalse("あ".isAlphabet)
    }

    func testIsHiragana() {
        XCTAssertTrue("".isHiragana, "空文字列はtrue")
        XCTAssertTrue("ひらけごま".isHiragana)
        XCTAssertFalse("アイウエオ".isHiragana)
    }

    func testIsOkuriAri() {
        XCTAssertFalse("".isOkuriAri, "空文字列はfalse")
        XCTAssertTrue("あr".isOkuriAri)
        XCTAssertFalse("あいうえお".isOkuriAri)
        XCTAssertFalse("い58".isOkuriAri)
        XCTAssertFalse("skk".isOkuriAri, "Abbrevの見出し")
        XCTAssertFalse("b".isOkuriAri)
        XCTAssertFalse("ん".isOkuriAri)
    }
}
