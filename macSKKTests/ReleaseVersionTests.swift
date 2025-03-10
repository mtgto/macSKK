// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

@testable import macSKK

final class ReleaseVersionTests: XCTestCase {
    func testComparable() {
        XCTAssertTrue(ver(1, 0, 0) > ver(0, 9, 9))
        XCTAssertTrue(ver(10, 0, 0) > ver(9, 9, 9))
        XCTAssertTrue(ver(0, 10, 0) > ver(0, 9, 9))
        XCTAssertTrue(ver(0, 0, 10) > ver(0, 0, 9))
    }

    func testInit() {
        XCTAssertEqual(try? ReleaseVersion(string: "1.2.30"), ver(1, 2, 30))
        XCTAssertNil(try? ReleaseVersion(string: "v1.0.0"), "数字3つ以外つけてはいけない")
        XCTAssertNil(try? ReleaseVersion(string: "2.0"), "数字は3つないといけない")
        XCTAssertNil(try? ReleaseVersion(string: "0.f.0"), "数字は10進数じゃないといけない")
        XCTAssertNil(try? ReleaseVersion(string: "0.1.0-beta1"), "ベータバージョンのような形式は受理しない")
    }

    private func ver(_ major: Int = 0, _ minor: Int = 0, _ patch: Int = 0) -> ReleaseVersion {
        return ReleaseVersion(major: major, minor: minor, patch: patch)
    }
}
