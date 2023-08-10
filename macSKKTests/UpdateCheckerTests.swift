// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

@testable import macSKK

final class UpdateCheckerTests: XCTestCase {
    func testParseDocument() throws {
        let xml = Bundle(for: Self.self).url(forResource: "releases", withExtension: "atom")!
        let doc = try XMLDocument(contentsOf: xml)
        let releases = try UpdateChecker().parseDocument(doc)
        XCTAssertEqual(releases.count, 2)
        XCTAssertEqual(releases.first?.version, ReleaseVersion(major: 0, minor: 1, patch: 1))
        XCTAssertEqual(releases.first?.url.absoluteString, "https://github.com/mtgto/macSKK/releases/tag/0.1.1")
        XCTAssertEqual(releases.first?.updated, ISO8601DateFormatter().date(from: "2023-08-09T09:21:49Z"))
        XCTAssertEqual(releases[1].version, ReleaseVersion(major: 0, minor: 1, patch: 0))
    }
}
