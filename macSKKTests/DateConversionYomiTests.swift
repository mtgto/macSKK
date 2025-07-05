// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

@testable import macSKK

final class DateConversionYomiTests: XCTestCase {
    func testInit() {
        XCTAssertNotNil(DateConversion.Yomi(dict: ["yomi": "きょう", "relative": "tomorrow"]))
        XCTAssertNil(DateConversion.Yomi(dict: ["yomi": "", "relative": "tomorrow"])) // 読みが空文字列
        XCTAssertNil(DateConversion.Yomi(dict: ["yomi": "きょう", "relative": "xxxx"])) // 現在との差分が不正
    }

    func testEncodeAndDecode() {
        // Test with yomi and relative
        let yomi = DateConversion.Yomi(dict: ["yomi": "きょう", "relative": "tomorrow"])
        XCTAssertNotNil(yomi)
        let encoded = yomi!.encode()
        let decoded = DateConversion.Yomi(dict: encoded)
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded!.yomi, yomi!.yomi)
        XCTAssertEqual(decoded!.relative, yomi!.relative)
        XCTAssertNotEqual(decoded!.id, yomi!.id) // idは毎回再生成されるので一致しない
    }

    func testTimeInterval() {
        let nowYomi = DateConversion.Yomi(yomi: "きょう", relative: .now)
        XCTAssertEqual(nowYomi.timeInterval, 0)

        let yesterdayYomi = DateConversion.Yomi(yomi: "きのう", relative: .yesterday)
        XCTAssertEqual(yesterdayYomi.timeInterval, -24 * 60 * 60)

        let tomorrowYomi = DateConversion.Yomi(yomi: "あした", relative: .tomorrow)
        XCTAssertEqual(tomorrowYomi.timeInterval, 24 * 60 * 60)
    }
}
