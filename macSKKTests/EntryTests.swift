// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

@testable import macSKK

final class EntryTests: XCTestCase {
    func testInit() throws {
        let entry = Entry(line: "あg /挙/揚/上/", dictId: "")
        XCTAssertEqual(entry?.yomi, "あg")
        XCTAssertEqual(entry?.candidates.map { $0.word }, ["挙", "揚", "上"])
    }

    func testDecode() {
        XCTAssertEqual(Entry(line: #"ao /(concat "and\057or")/"#, dictId: "")?.candidates.first?.word, "and/or")
    }

    func testAnnotation() throws {
        guard let entry = Entry(line: "けい /京;10^16/", dictId: "") else { XCTFail(); return }
        XCTAssertEqual(entry.candidates[0].word, "京")
        XCTAssertEqual(entry.candidates[0].annotation?.text, "10^16")
        XCTAssertEqual(Entry(line: "あ /亜;*個人注釈/", dictId: "")?.candidates.first?.annotation?.text, "個人注釈")
    }

    func testOkuriBlock() throws {
        XCTAssertEqual(Entry(line: "おおk /大/多/[く/多/]/[き/大/]/", dictId: "")?.candidates.map { $0.word }, ["大", "多", "多", "大"])
        XCTAssertEqual(Entry(line: "いt /[った/行/言/]/", dictId: "")?.candidates.map { $0.word }, ["行", "言"])
    }

    func testInvalidLine() {
        XCTAssertNil(Entry(line: "", dictId: ""))
        XCTAssertNil(Entry(line: ";こめんと /コメント/", dictId: ""))
        XCTAssertNil(Entry(line: "い/胃/", dictId: ""), "読みと変換候補の間にスペースがない")
        XCTAssertNil(Entry(line: "い  /胃/", dictId: ""), "読みと変換候補の間にスペースが2つある")
        XCTAssertNil(Entry(line: "い /胃/意", dictId: ""), "末尾がスラッシュで終わらない")
        XCTAssertNil(Entry(line: "い //", dictId: ""), "変換候補が空")
        XCTAssertNil(Entry(line: "い /胃//意/", dictId: ""), "変換候補が空")
        XCTAssertNil(Entry(line: "い /胃/意//", dictId: ""), "変換候補が空")
        XCTAssertNil(Entry(line: "いt /[]/", dictId: ""), "送り仮名ブロックが空")
        XCTAssertNil(Entry(line: "いt /[った]/", dictId: ""), "送り仮名ブロックの変換候補が空")
        XCTAssertNil(Entry(line: "いt /[った/行]/", dictId: ""), "送り仮名ブロックの変換候補の末尾にスラッシュがない")
        XCTAssertNil(Entry(line: "いt /[った//]/", dictId: ""), "変換候補が空")
        XCTAssertNil(Entry(line: "いt /[った/行/", dictId: ""), "送り仮名ブロックが閉じていない")
    }
}
