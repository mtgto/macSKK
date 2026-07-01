// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
@testable import macSKK

final class SKKServDestinationTests: XCTestCase {
    func testEncodeYomiEUC() throws {
        let destination = SKKServDestination(host: "localhost", port: 1178, requestEncoding: .japaneseEUC, responseEncoding: .japaneseEUC)
        // EUC-JPの普通の見出しはそのままEUC-JPバイト列になる
        XCTAssertEqual(destination.encodeYomi("へんかん"), "へんかん".data(using: .japaneseEUC))
        // EUC-JPは "ゔ" を表現できないので "う゛" にフォールバックしてからエンコードする
        XCTAssertEqual(destination.encodeYomi("ゔぁいおりん"), "う゛ぁいおりん".data(using: .japaneseEUC))
    }

    func testEncodeYomiUTF8() throws {
        let destination = SKKServDestination(host: "localhost", port: 1178, requestEncoding: .utf8, responseEncoding: .utf8)
        // UTF-8では普通の見出しはそのままUTF-8バイト列になる
        XCTAssertEqual(destination.encodeYomi("へんかん"), "へんかん".data(using: .utf8))
        // UTF-8は "ゔ" を表現できるので置換せずネイティブに送る
        XCTAssertEqual(destination.encodeYomi("ゔぁいおりん"), "ゔぁいおりん".data(using: .utf8))
    }

    // requestEncodingがエンコードを決め、responseEncodingには影響されないこと
    func testEncodeYomiUsesRequestEncoding() throws {
        let destination = SKKServDestination(host: "localhost", port: 1178, requestEncoding: .japaneseEUC, responseEncoding: .utf8)
        XCTAssertEqual(destination.encodeYomi("ゔ"), "う゛".data(using: .japaneseEUC))
    }

    func testDecodeResponseUTF8Found() throws {
        let destination = SKKServDestination(host: "localhost", port: 1178, requestEncoding: .utf8, responseEncoding: .utf8)
        XCTAssertEqual(destination.decodeResponse("1/変換/返還/\n".data(using: .utf8)!), "1/変換/返還/\n")
    }

    func testDecodeResponseEUCFound() throws {
        let destination = SKKServDestination(host: "localhost", port: 1178, requestEncoding: .japaneseEUC, responseEncoding: .japaneseEUC)
        XCTAssertEqual(destination.decodeResponse("1/変換/返還/\n".data(using: .japaneseEUC)!), "1/変換/返還/\n")
    }

    // 応答UTF-8設定なのに候補なし応答がEUCエコーで返る混在サーバ:
    // エラーにせず候補なし ("1/" で始まらない文字列) として扱えること
    func testDecodeResponseUTF8ButEucNotFound() throws {
        let destination = SKKServDestination(host: "localhost", port: 1178, requestEncoding: .japaneseEUC, responseEncoding: .utf8)
        let eucNotFound = "4へんかん".data(using: .japaneseEUC)!  // UTF-8としては不正なバイト列
        let result = try XCTUnwrap(destination.decodeResponse(eucNotFound))
        XCTAssertFalse(result.hasPrefix("1/"))  // 上位層で候補なし扱いになる
        XCTAssertEqual(result.first, "4")
    }

    // 候補あり ("1") なのにデコードできないときは候補を失わないようnilを返す
    func testDecodeResponseUndecodableFound() throws {
        let destination = SKKServDestination(host: "localhost", port: 1178, requestEncoding: .utf8, responseEncoding: .utf8)
        let broken = Data([0x31, 0x2f, 0xa4, 0xd8, 0x2f])  // "1/" + 不正なUTF-8 + "/"
        XCTAssertNil(destination.decodeResponse(broken))
    }

    func testDecodeResponseEmpty() throws {
        let utf8 = SKKServDestination(host: "localhost", port: 1178, requestEncoding: .utf8, responseEncoding: .utf8)
        XCTAssertEqual(utf8.decodeResponse(Data()), "")
        let euc = SKKServDestination(host: "localhost", port: 1178, requestEncoding: .japaneseEUC, responseEncoding: .japaneseEUC)
        XCTAssertEqual(euc.decodeResponse(Data()), "")
    }
}
