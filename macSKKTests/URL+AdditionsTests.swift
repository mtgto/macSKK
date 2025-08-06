// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

@testable import macSKK

final class URLAdditionsTests: XCTestCase {
    func testIsLoadable() throws {
        let kanaRuleFileURL = Bundle.main.url(forResource: "kana-rule", withExtension: "conf")!
        XCTAssertTrue(try kanaRuleFileURL.isReadable())
        let applications = URL(fileURLWithPath: "/Applications")
        XCTAssertFalse(try applications.isReadable())
    }
}
