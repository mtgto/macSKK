// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

@testable import macSKK

final class WorkaroundApplicationTests: XCTestCase {
    func testInitWithDict() throws {
        XCTAssertNil(WorkaroundApplication([:]))
        // bundleIdentifierとinsertBlankStringのどちらかが欠けていたら不正な設定として扱う
        XCTAssertNil(WorkaroundApplication(["insertBlankString": true]))
        XCTAssertNil(WorkaroundApplication(["bundleIdentifier": "com.example.Foo"]))

        let workaround = try XCTUnwrap(
            WorkaroundApplication([
                "bundleIdentifier": "com.example.Foo",
                "insertBlankString": true,
                "treatFirstCharacterAsMarkedText": true,
                "showMarkerWhenEmpty": true,
            ]))
        XCTAssertEqual(workaround.bundleIdentifier, "com.example.Foo")
        XCTAssertTrue(workaround.insertBlankString)
        XCTAssertTrue(workaround.treatFirstCharacterAsMarkedText)
        XCTAssertTrue(workaround.showMarkerWhenEmpty)
        XCTAssertEqual(workaround.id, "com.example.Foo")
    }

    /// 古いバージョンが保存した設定を読み込めること
    func testInitWithDictOfOlderVersion() throws {
        let workaround = try XCTUnwrap(
            WorkaroundApplication([
                "bundleIdentifier": "com.example.Foo",
                "insertBlankString": true,
            ]))
        // treatFirstCharacterAsMarkedTextはv2.1+ で追加されたのでfalse
        XCTAssertFalse(workaround.treatFirstCharacterAsMarkedText)
        // showMarkerWhenEmptyはv2.15+ で追加されたのでfalse
        XCTAssertFalse(workaround.showMarkerWhenEmpty)
    }

    func testEncode() {
        let workaround = WorkaroundApplication(
            bundleIdentifier: "com.example.Foo",
            insertBlankString: true,
            treatFirstCharacterAsMarkedText: false,
            showMarkerWhenEmpty: true)

        let encoded = workaround.encode()

        XCTAssertEqual(encoded["bundleIdentifier"] as? String, "com.example.Foo")
        XCTAssertEqual(encoded["insertBlankString"] as? Bool, true)
        XCTAssertEqual(encoded["treatFirstCharacterAsMarkedText"] as? Bool, false)
        XCTAssertEqual(encoded["showMarkerWhenEmpty"] as? Bool, true)
        // アイコンと表示名は実行時にアプリから取得するものなので保存しない
        XCTAssertEqual(encoded.count, 4)
    }

    /// encodeした設定をそのまま読み戻せること
    func testEncodeAndInitRoundTrip() throws {
        for insertBlankString in [true, false] {
            for treatFirstCharacterAsMarkedText in [true, false] {
                for showMarkerWhenEmpty in [true, false] {
                    let workaround = WorkaroundApplication(
                        bundleIdentifier: "com.example.Foo",
                        insertBlankString: insertBlankString,
                        treatFirstCharacterAsMarkedText: treatFirstCharacterAsMarkedText,
                        showMarkerWhenEmpty: showMarkerWhenEmpty,
                        icon: NSImage(),
                        displayName: "Foo")

                    let decoded = try XCTUnwrap(WorkaroundApplication(workaround.encode()))

                    XCTAssertEqual(decoded.bundleIdentifier, workaround.bundleIdentifier)
                    XCTAssertEqual(decoded.insertBlankString, workaround.insertBlankString)
                    XCTAssertEqual(
                        decoded.treatFirstCharacterAsMarkedText, workaround.treatFirstCharacterAsMarkedText)
                    XCTAssertEqual(decoded.showMarkerWhenEmpty, workaround.showMarkerWhenEmpty)
                    // アイコンと表示名は保存していないので復元されない
                    XCTAssertNil(decoded.icon)
                    XCTAssertNil(decoded.displayName)
                }
            }
        }
    }

    /// UserDefaultsに保存できる型だけで構成されていること。
    /// 保存できない値が混ざるとplistの書き込みに失敗して設定が保存されなくなる。
    func testEncodeIsPropertyList() {
        let encoded = WorkaroundApplication(
            bundleIdentifier: "com.example.Foo",
            insertBlankString: true,
            treatFirstCharacterAsMarkedText: true,
            showMarkerWhenEmpty: true
        ).encode()
        XCTAssertTrue(PropertyListSerialization.propertyList(encoded, isValidFor: .binary))
    }
}
