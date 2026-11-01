// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

@testable import macSKK

/// ``SearchableDict`` のextensionにあるデフォルト実装のテスト。
///
/// 準拠する型 (``MemoryDict``, ``ReadonlyMemoryDict``) のどちらでも同じ結果になることを確認する。
final class SearchableDictTests: XCTestCase {
    private let entries: [String: [Word]] = [
        "あき>": [Word("空き")],
        "あき": [Word("秋")],
        ">し": [Word("氏")],
        "し": [Word("詩")],
        "いt": [Word("言"), Word("行", okuri: "った")],
    ]

    func testReferWithOptionMemoryDict() {
        assertReferWithOption(MemoryDict(entries: entries))
    }

    func testReferWithOptionReadonlyMemoryDict() {
        assertReferWithOption(ReadonlyMemoryDict(entries: entries))
    }

    private func assertReferWithOption(_ dict: some SearchableDict, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(dict.refer("あき", option: nil), [Word("秋")], file: file, line: line)
        XCTAssertEqual(dict.refer("あき", option: .prefix), [Word("空き")], file: file, line: line)
        XCTAssertEqual(dict.refer("あき", option: .suffix), [], file: file, line: line)
        XCTAssertEqual(dict.refer("し", option: nil), [Word("詩")], file: file, line: line)
        XCTAssertEqual(dict.refer("し", option: .suffix), [Word("氏")], file: file, line: line)
        XCTAssertEqual(dict.refer("し", option: .prefix), [], file: file, line: line)
        XCTAssertEqual(dict.refer("いt", option: nil), [Word("言"), Word("行", okuri: "った")], file: file, line: line)
        XCTAssertEqual(dict.refer("いt", option: .okuri("った")), [Word("行", okuri: "った"), Word("言")],
                       "送り仮名が合致するものを先に返す", file: file, line: line)
        XCTAssertEqual(dict.refer("いk", option: .okuri("った")), [], "読みがなければ空", file: file, line: line)
        XCTAssertEqual(dict.refer("なし", option: nil), [], file: file, line: line)
    }
}
