// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
@testable import macSKK

final class SKKServDictTests: XCTestCase {
    struct MockedSKKServService: SKKServServiceProtocol {
        let response: String

        func refer(yomi: String, destination: SKKServDestination, timeout: TimeInterval) throws -> String {
            return response
        }

        func disconnect() throws {}
    }

    let destination = SKKServDestination(host: "localhost", port: 1178, encoding: .japaneseEUC)

    func testRefer() async throws {
        let service = MockedSKKServService(response: "1/変換/返還/")
        let dict = SKKServDict(destination: destination, service: service)
        XCTAssertEqual(dict.refer("へんかん", option: nil).map { $0.word }, ["変換", "返還"])
    }

    func testReferNotFound() async throws {
        let service = MockedSKKServService(response: "4へんかん")
        let dict = SKKServDict(destination: destination, service: service)
        XCTAssertEqual(dict.refer("へんかん", option: nil).map { $0.word }, [])
    }
}
