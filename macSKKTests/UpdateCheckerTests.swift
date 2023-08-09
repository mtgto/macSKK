// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

@testable import macSKK

final class UpdateCheckerTests: XCTestCase {
    func testCallSampleXPC() async throws {
        let updateChecker = UpdateChecker()
        let response = try await updateChecker.callSampleXPC()
        XCTAssertEqual(response, "HELLO")
    }
}
