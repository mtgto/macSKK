
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
@testable import macSKK

final class DictSettingTests: XCTestCase {
    func testInitWithDict() throws {
        XCTAssertNil(DictSetting([:]))
        let dictSetting = try XCTUnwrap(DictSetting([
            "filename": "foo",
            "enabled": true,
            "encoding": String.Encoding.utf8.rawValue,
        ]))
        //
        // typeはv2.2.1まで設定としてなかったのでtradditional
        XCTAssertEqual(dictSetting.type, .traditional(.utf8))
        // saveToUserDictはv.2.2.1まで設定としてなかったのでtrue
        XCTAssertTrue(dictSetting.saveToUserDict)
    }
}
