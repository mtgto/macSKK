// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
@testable import macSKK

final class SKKServDestinationTests: XCTestCase {
    func testEncodeYomiEUC() throws {
        let destination = SKKServDestination(host: "localhost", port: 1178, encoding: .japaneseEUC)
        // EUC-JPの普通の見出しはそのままEUC-JPバイト列になる
        XCTAssertEqual(destination.encodeYomi("へんかん"), "へんかん".data(using: .japaneseEUC))
        // EUC-JPは "ゔ" を表現できないので "う゛" にフォールバックしてからエンコードする
        XCTAssertEqual(destination.encodeYomi("ゔぁいおりん"), "う゛ぁいおりん".data(using: .japaneseEUC))
    }

    func testEncodeYomiUTF8() throws {
        let destination = SKKServDestination(host: "localhost", port: 1178, encoding: .utf8)
        // UTF-8では普通の見出しはそのままUTF-8バイト列になる
        XCTAssertEqual(destination.encodeYomi("へんかん"), "へんかん".data(using: .utf8))
        // UTF-8は "ゔ" を表現できるので置換せずネイティブに送る
        XCTAssertEqual(destination.encodeYomi("ゔぁいおりん"), "ゔぁいおりん".data(using: .utf8))
    }
}
