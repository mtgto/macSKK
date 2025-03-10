// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

@testable import macSKK

final class UpdateCheckerTests: XCTestCase {
    func testDecode() throws {
        let fileURL = Bundle(for: Self.self).url(forResource: "release", withExtension: "json")!
        let data = try Data(NSData(contentsOf: fileURL))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let release = try decoder.decode(Release.self, from: data)
        XCTAssertEqual(release.version, ReleaseVersion(major: 1, minor: 11, patch: 0))
        XCTAssertEqual(release.updated.ISO8601Format(), "2025-02-23T11:36:20Z")
        XCTAssertEqual(release.url.absoluteString, "https://github.com/mtgto/macSKK/releases/tag/1.11.0")
        XCTAssertEqual(release.content, "- 補完候補をSKKServから取得するテスト機能を設定画面に追加 (#309)\r\n- abbrevモードでTab補完すると前のモードに戻れなくなるバグを修正 (#312)\r\n- Spaceにスペースキー以外を割り当てているときnormalモードでは入力されたキーの入力を優先する (#310)\r\n- 起動時に設定変更したようなログが出ていたのを修正 (#313)\r\n- ひらがなモードで文字未入力時はPageDnなどの特殊キーを無視する (#314)\r\n- 選択文字列から変換候補を逆引きして読みとして変換を再度開始 (再変換) (#294)")
    }
}
