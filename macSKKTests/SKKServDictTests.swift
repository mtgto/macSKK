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

        func completion(yomi: String, destination: macSKK.SKKServDestination, timeout: TimeInterval) throws -> String {
            return response
        }

        func disconnect() throws {}
    }

    let destination = SKKServDestination(host: "localhost", port: 1178, encoding: .japaneseEUC)

    func testRefer() async throws {
        let service = MockedSKKServService(response: "1/変換/返還/")
        let dict = SKKServDict(destination: destination, service: service, saveToUserDict: false)
        XCTAssertEqual(dict.refer("へんかん", option: nil).map { $0.word }, ["変換", "返還"])
    }

    func testReferNotFound() async throws {
        let service = MockedSKKServService(response: "4へんかん")
        let dict = SKKServDict(destination: destination, service: service, saveToUserDict: false)
        XCTAssertEqual(dict.refer("へんかん", option: nil).map { $0.word }, [])
    }

    func testFindCompletion() async throws {
        let service = MockedSKKServService(response: "1/ほかん/ほかく/")
        var dict = SKKServDict(destination: destination, service: service, saveToUserDict: false)
        XCTAssertEqual(dict.findCompletions(prefix: "ほか"), ["ほかん", "ほかく"])
        // 重複した補完候補、読みと同じ候補、読みを接頭辞としてもたない候補は除外する
        dict = SKKServDict(destination: destination,
                           service: MockedSKKServService(response: "1/ほかん/ほかん/ほか/ほげ/"),
                           saveToUserDict: false)
        XCTAssertEqual(dict.findCompletions(prefix: "ほか"), ["ほかん"])
    }

    func testFindCompletionNotFound() async throws {
        let service = MockedSKKServService(response: "4ほかん")
        let dict = SKKServDict(destination: destination, service: service, saveToUserDict: false)
        XCTAssertEqual(dict.findCompletions(prefix: "ほかん"), [])
    }
}
