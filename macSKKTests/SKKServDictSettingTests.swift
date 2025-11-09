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
    }
}
