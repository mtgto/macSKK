// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
@testable import macSKK

final class SKKServDictTests: XCTestCase {
    let destination = SKKServDestination(host: "localhost", port: 1178, encoding: .japaneseEUC)

    func testRefer() async throws {
        let dict = SKKServDict(destination: destination)
    }
}
