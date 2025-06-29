// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

@testable import macSKK

final class DateConversionYomiTests: XCTestCase {
    func testEncodeAndDecode() throws {
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

    func testTimeInterval() throws {
        let nowYomi = DateConversion.Yomi(yomi: "きょう", relative: .now)
        XCTAssertEqual(nowYomi.timeInterval, 0)

        let yesterdayYomi = DateConversion.Yomi(yomi: "きのう", relative: .yesterday)
        XCTAssertEqual(yesterdayYomi.timeInterval, -24 * 60 * 60)

        let tomorrowYomi = DateConversion.Yomi(yomi: "あした", relative: .tomorrow)
        XCTAssertEqual(tomorrowYomi.timeInterval, 24 * 60 * 60)
    }
}
