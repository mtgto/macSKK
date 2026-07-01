// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
@testable import macSKK

final class SKKServDictSettingTests: XCTestCase {
    func testInitWithDict() throws {
        XCTAssertNil(SKKServDictSetting([:]))
        let skkServDictSetting = try XCTUnwrap(SKKServDictSetting([
            "enabled": true,
            "address": "127.0.0.1",
            "port": UInt16(1178),
            "encoding": String.Encoding.utf8.rawValue,
        ]))
        // v2.2.1まではsaveToUserDictは設定としてなかった。辞書にエントリがない場合はtrue
        XCTAssertTrue(skkServDictSetting.saveToUserDict)
        // v2.5.0まではenableCompletionは設定としてなかった。辞書にエントリがない場合はfalse
        XCTAssertFalse(skkServDictSetting.enableCompletion)
        // 旧設定 (単一 "encoding") からの移行: requestは旧挙動どおりEUC-JP固定、responseは旧 "encoding"
        XCTAssertEqual(skkServDictSetting.requestEncoding, .japaneseEUC)
        XCTAssertEqual(skkServDictSetting.responseEncoding, .utf8)
    }

    func testInitWithNewEncodings() throws {
        let setting = try XCTUnwrap(SKKServDictSetting([
            "enabled": true,
            "address": "127.0.0.1",
            "port": UInt16(1178),
            "requestEncoding": String.Encoding.utf8.rawValue,
            "responseEncoding": String.Encoding.japaneseEUC.rawValue,
        ]))
        XCTAssertEqual(setting.requestEncoding, .utf8)
        XCTAssertEqual(setting.responseEncoding, .japaneseEUC)
    }

    // encode() は新キーに加えてダウングレード互換の "encoding" (= responseEncoding) も書く
    func testEncodeKeepsLegacyEncodingKey() throws {
        let setting = SKKServDictSetting(
            enabled: true, address: "127.0.0.1", port: 1178,
            requestEncoding: .utf8, responseEncoding: .japaneseEUC,
            saveToUserDict: true, enableCompletion: false)
        let dict = setting.encode()
        XCTAssertEqual(dict["requestEncoding"] as? UInt, String.Encoding.utf8.rawValue)
        XCTAssertEqual(dict["responseEncoding"] as? UInt, String.Encoding.japaneseEUC.rawValue)
        XCTAssertEqual(dict["encoding"] as? UInt, String.Encoding.japaneseEUC.rawValue)
    }
}
