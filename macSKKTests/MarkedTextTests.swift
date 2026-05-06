// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

@testable import macSKK

final class MarkedTextTests: XCTestCase {
    func testAttributedStringShow() {
        XCTAssertEqual(String(MarkedText([.markerCompose, .plain("あ"), .cursor]).attributedString(true).characters), "▽あ")
        XCTAssertEqual(String(MarkedText([.markerSelect, .emphasized("阿"), .cursor]).attributedString(true).characters), "▼阿")
        // abbrevなど未確定文字列が空のケース
        XCTAssertEqual(String(MarkedText([.markerCompose, .cursor]).attributedString(true).characters), "▽")
    }

    func testAttributedStringHide() {
        XCTAssertEqual(String(MarkedText([.markerCompose, .plain("あ"), .cursor]).attributedString(false).characters), "あ")
        XCTAssertEqual(String(MarkedText([.markerSelect, .emphasized("阿"), .cursor]).attributedString(false).characters), "阿")
        // 非表示時は未確定文字列が空でもマーカーを表示しない
        XCTAssertEqual(String(MarkedText([.markerCompose, .cursor]).attributedString(false).characters), "")
    }

    func testCursorRange() {
        // カーソルがない場合は末尾にカーソルが追加され cursorRange は nil
        XCTAssertNil(MarkedText([.markerCompose, .plain("あ")]).cursorRange(true))
        // カーソル位置がマーカーと文字数の合算になっている
        XCTAssertEqual(MarkedText([.markerCompose, .plain("あ"), .cursor]).cursorRange(true), NSRange(location: 2, length: 0))
        // マーカー非表示時はカーソル位置にマーカー分が含まれない
        XCTAssertEqual(MarkedText([.markerCompose, .plain("あ"), .cursor]).cursorRange(false), NSRange(location: 1, length: 0))
        // カーソルが中間位置にある場合
        XCTAssertEqual(MarkedText([.markerCompose, .plain("あ"), .cursor, .plain("い")]).cursorRange(true), NSRange(location: 2, length: 0))
    }
}
