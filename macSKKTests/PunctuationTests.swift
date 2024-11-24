// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

@testable import macSKK

final class PunctuationTests: XCTestCase {
    func testInit() {
        guard var punctuation = Punctuation(rawValue: 0) else { XCTFail(); return } // default, default
        XCTAssertEqual(punctuation.comma, .default)
        XCTAssertEqual(punctuation.period, .default)
        punctuation = Punctuation(comma: .comma, period: .maru)
        XCTAssertEqual(punctuation.comma, .comma)
        XCTAssertEqual(punctuation.period, .maru)
        XCTAssertEqual(punctuation.rawValue, 256 | 2)
        let punctuation2 = Punctuation(rawValue: punctuation.rawValue)
        XCTAssertEqual(punctuation2?.comma, .comma)
        XCTAssertEqual(punctuation2?.period, .maru)
    }
}
