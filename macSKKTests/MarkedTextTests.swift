// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

@testable import macSKK

final class MarkedTextTests: XCTestCase {
    func testAttributedStringAlways() {
        XCTAssertEqual(String(MarkedText([.markerCompose, .plain("あ"), .cursor]).attributedString(.always).characters), "▽あ")
        XCTAssertEqual(String(MarkedText([.markerSelect, .emphasized("阿"), .cursor]).attributedString(.always).characters), "▼阿")
        // abbrevなど未確定文字列が空のケース
        XCTAssertEqual(String(MarkedText([.markerCompose, .cursor]).attributedString(.always).characters), "▽")
    }

    func testAttributedStringMinimal() {
        XCTAssertEqual(String(MarkedText([.markerCompose, .plain("あ"), .cursor]).attributedString(.minimal).characters), "あ")
        XCTAssertEqual(String(MarkedText([.markerSelect, .emphasized("阿"), .cursor]).attributedString(.minimal).characters), "阿")
        // abbrevなど未確定文字列が空のときはフォールバックで▽を表示する
        XCTAssertEqual(String(MarkedText([.markerCompose, .cursor]).attributedString(.minimal).characters), "▽")
        XCTAssertEqual(String(MarkedText([.markerCompose, .plain(""), .cursor]).attributedString(.minimal).characters), "▽")
    }

    func testAttributedStringNever() {
        XCTAssertEqual(String(MarkedText([.markerCompose, .plain("あ"), .cursor]).attributedString(.never).characters), "あ")
        XCTAssertEqual(String(MarkedText([.markerSelect, .emphasized("阿"), .cursor]).attributedString(.never).characters), "阿")
        // neverは未確定文字列が空でもマーカーを表示しない
        XCTAssertEqual(String(MarkedText([.markerCompose, .cursor]).attributedString(.never).characters), "")
    }

    func testCursorRange() {
        // カーソルがない場合は末尾にカーソルが追加され cursorRange は nil
        XCTAssertNil(MarkedText([.markerCompose, .plain("あ")]).cursorRange(.always))
        // カーソル位置がマーカーと文字数の合算になっている
        XCTAssertEqual(MarkedText([.markerCompose, .plain("あ"), .cursor]).cursorRange(.always), NSRange(location: 2, length: 0))
        // マーカー非表示時はカーソル位置にマーカー分が含まれない
        XCTAssertEqual(MarkedText([.markerCompose, .plain("あ"), .cursor]).cursorRange(.never), NSRange(location: 1, length: 0))
        // カーソルが中間位置にある場合
        XCTAssertEqual(MarkedText([.markerCompose, .plain("あ"), .cursor, .plain("い")]).cursorRange(.always), NSRange(location: 2, length: 0))
    }
}
