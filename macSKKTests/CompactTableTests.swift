// SPDX-FileCopyrightText: 2026 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

@testable import macSKK

final class CompactTableTests: XCTestCase {
    func testLookup() {
        let annotation = Annotation(dictId: "d", text: "stomach")
        let table = CompactTable(
            entries: [
                ("あ", [Word("阿")]),
                ("い", [Word("胃", okuri: nil, annotation: annotation)]),
            ])
        XCTAssertEqual(table.words(of: "あ"), [Word("阿")])
        XCTAssertEqual(table.words(of: "い")?.first?.annotation, annotation)
        XCTAssertNil(table.words(of: "う"))
        XCTAssertNil(table.words(of: ""))
    }

    func testDuplicateYomisAreConcatenatedInOrder() {
        let table = CompactTable(
            entries: [
                ("あ", [Word("亜")]),
                ("い", [Word("胃")]),
                ("あ", [Word("阿"), Word("唖")]),
            ])
        XCTAssertEqual(table.words(of: "あ")?.map(\.word), ["亜", "阿", "唖"])
        XCTAssertEqual(table.count, 2)
        XCTAssertEqual(table.keys, ["あ", "い"])
    }

    func testDuplicateYomisInSortedInput() {
        let table = CompactTable(
            entries: [
                ("あ", [Word("亜")]),
                ("あ", [Word("阿")]),
                ("い", [Word("胃")]),
            ])
        XCTAssertEqual(table.words(of: "あ")?.map(\.word), ["亜", "阿"])
        XCTAssertEqual(table.keys, ["あ", "い"])
    }

    func testUnsortedInputIsSorted() {
        let yomis = ["う", "い", "あ", "Greek", "cyrillic"]
        let table = CompactTable(entries: yomis.map { ($0, [Word($0 + "!")]) })
        XCTAssertEqual(table.keys, ["Greek", "cyrillic", "あ", "い", "う"])
        for yomi in yomis {
            XCTAssertEqual(table.words(of: yomi)?.map(\.word), [yomi + "!"])
        }
        XCTAssertEqual(table.allEntries().map(\.yomi), table.keys)
        XCTAssertEqual(table.allEntries().map(\.words), table.keys.map { [Word($0 + "!")] })
    }

    func testCanonicallyEquivalentYomis() {
        // "が" のNFC (U+304C) とNFD (U+304B U+3099) はStringとしては等しいので同じ読みとして扱う
        let nfc = "\u{304C}"
        let nfd = "\u{304B}\u{3099}"
        let table = CompactTable(
            entries: [
                (nfc, [Word("蛾")]),
                ("あ", [Word("亜")]),
                (nfd, [Word("我")]),
            ])
        XCTAssertEqual(table.count, 2)
        XCTAssertEqual(table.words(of: nfc)?.map(\.word), ["蛾", "我"])
        XCTAssertEqual(table.words(of: nfd)?.map(\.word), ["蛾", "我"])
    }

    func testOkuriIsPreserved() {
        let table = CompactTable(entries: [("おおk", [Word("多", okuri: "く")])])
        XCTAssertEqual(table.words(of: "おおk")?.first?.okuri, "く")
    }

    func testEmpty() {
        let table = CompactTable(entries: [])
        XCTAssertEqual(table.count, 0)
        XCTAssertEqual(table.keys, [])
        XCTAssertNil(table.words(of: "あ"))
        XCTAssertTrue(table.allEntries().isEmpty)
    }
}
